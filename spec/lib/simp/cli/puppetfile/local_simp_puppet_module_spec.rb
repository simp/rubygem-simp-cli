require 'simp/cli/puppetfile/local_simp_puppet_module'
require 'spec_helper'

describe Simp::Cli::Puppetfile::LocalSimpPuppetModule do
  describe '#foo' do #FIXME
    before :each do
      files_dir = File.join(__dir__, 'files')
      usr_mod_dir  = '/usr/share/simp/modules'
      simp_git_dir = '/usr/share/simp/git/puppet_modules'
      modules = {
        'simplib' => {},
      }
      modules.each do |k,v|
        modules[k][:metadata_json_path] = "#{usr_mod_dir}/#{k}/metadata.json"
        modules[k][:metadata] = JSON.parse(File.read(File.join(files_dir,"#{k}.metadata.json")))
        modules[k][:git_tag_l] = File.read(File.join(files_dir,"#{k}.git_tag_-l.txt"))
      end
      metadata_json_list = modules.map{|k,v| v[:metadata_json_path] }
      collection  = LocalSimpPuppetModules.new(usr_mod_dir, simp_git_dir)
      allow(collection).to receive(:metadata_json_files).and_return(metadata_json_list)
      modules.each do |k,mod|
        name = modules[k][:metadata]['name']
        data = modules[k][:metadata]
        obj  = LocalSimpPuppetModule.new(data,simp_git_dir)
        allow(collection).to receive(:metadata).with(modules[k][:metadata_json_path]).and_return(data)
        allow(obj).to receive(:local_git_repo_path).and_return("#{simp_git_dir}/#{name}.git")
        allow(obj).to receive(:tag_exists_for_version?).and_return(true)
        allow(LocalSimpPuppetModule).to receive(:new).with(
          hash_including('name' => name), simp_git_dir
        ).and_return(obj)

      end

      allow(Simp::Cli::Puppetfile::LocalSimpPuppetModule).to receive(:new).and_return(
        object_double('Fake LocalSimpPuppetModules', :to_s => 'fake modules')
      )
    end
    it 'foo' do # FIXME
      puts 'WAT'
      subject.run ['generate']
    end
  end
end
