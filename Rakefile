require 'rubygems'
require 'cucumber'
require 'cucumber/rake/task'

Cucumber::Rake::Task.new(:test) do |t|
desc "Run API backend integration tests"
  t.cucumber_opts = "features plugins/*/features"
end


namespace :db do
  desc "Seeds the db with test/mock data"
  task :seed do
    load "irb.ru"
    puts "Seeding database..."

    App::Model::Elasticsearch.configure(App::Config.get('database.elasticsearch', {}))

    models = Hash[App::Model::Elasticsearch.implementers.to_a.collect{|i| [i.index_name, i] }]

    models.each do |index, model|
      puts "Syncing model #{model.name}..."
      model.sync_schema()
    end
  end

  desc "Deletes all indices and recreates them empty.  EXTREMELY DANGEROUS!"
  task :nuke do
    load "irb.ru"
    puts "Nuking database..."

    App::Model::Elasticsearch.configure(App::Config.get('database.elasticsearch', {}))

    models = Hash[App::Model::Elasticsearch.implementers.to_a.collect{|i| [i.index_name, i] }]

    models.each do |index, model|
      begin
        puts "Nuking model #{model.name}..."
        model.connection.indices.delete({
          :index => model.index_name()
        })
      rescue
        nil
      end

      model.sync_schema()
    end
  end
end

# utilities for managing static assets
namespace :assets do
  desc "Generate minified production-ready static resources from installed plugins"
  task :generate, :plugins do |t, plugins|
    p = (plugins[:plugins] || Dir["plugins/*"].collect{|d| File.basename(d) }.sort.join(','))
    plugins = p.split(/\W/) unless plugins.is_a?(Array)

  # hack?  yes.
    system "./bin/regen-assets.sh #{plugins.join(' ')}"
  end
end


# generate CA and Validation SSL
namespace :ssl do
  desc "Generate SSL certificates"

  task :generate do |t|
    ca_base         = './config/ssl/ca'
    validation_pem  = './config/ssl/validation.pem'
    raise "Cannot generate validation certificate, #{validation_pem} already exists!" if File.size?(validation_pem)


    ENV['PROJECT_ROOT'] = File.dirname(File.expand_path(__FILE__))

    require 'openssl'
    require './lib/app'

    App::Config.load(ENV['PROJECT_ROOT'])

    subject         = "#{ App::Config.get!('global.authentication.methods.ssl.subject_prefix').sub(/\/$/,'') }/OU=System/CN=Validation"


  # load CA certificate and keys
    ca_crt = OpenSSL::X509::Certificate.new(File.read("#{ca_base}.crt"))
    ca_key = OpenSSL::PKey::RSA.new(File.read("#{ca_base}.key"))

  # new validation certificate
    validation_crt = OpenSSL::X509::Certificate.new
    validation_crt.subject = OpenSSL::X509::Name.parse(subject)
    validation_crt.issuer = ca_crt.issuer
    validation_crt.not_before = Time.now
    validation_crt.not_after = Time.now + ((Integer(App::Config.get('global.authentication.methods.ssl.client.max_age')) rescue 365) * 24 * 60 * 60)
    validation_crt.public_key = ca_key.public_key
    validation_crt.serial = 0x0
    validation_crt.version = 2

  # add extensions (don't entirely know what these do)
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = validation_crt
    ef.issuer_certificate = ca_crt

    validation_crt.extensions = [
      ef.create_extension("basicConstraints","CA:TRUE", true),
      ef.create_extension("subjectKeyIdentifier", "hash")
    ]

  # sign it
    validation_crt.sign(ca_key, OpenSSL::Digest::SHA256.new)

  # save it
    File.open(validation_pem, "w") do |f|
      f.write(validation_crt.to_pem)
    end
  end
end
