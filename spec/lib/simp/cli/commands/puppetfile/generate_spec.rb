require 'simp/cli/commands/puppetfile/generate'
require 'spec_helper'

describe Simp::Cli::Commands::Puppetfile::Generate do
  describe '#foo' do
    before :each do
      files_dir = File.join(__dir__, 'files')
      usr_mod_dir  = '/usr/share/simp/modules'
      simp_git_dir = '/usr/share/simp/git/puppet_modules'

      modules = {
        'simplib' => { rpm: 'pupmod-simp-simplib-3.11.1-0.noarch' },
        'stdlib'  => { rpm: 'pupmod-puppetlabs-stdlib-4.25.1-0.noarch' },
      }
      modules.each do |k,v|
        modules[k][:rpm_ql] = File.read(File.join(files_dir,"#{k}.rpm_files.txt"))
        modules[k][:metadata] = JSON.parse(File.read(File.join(files_dir,"#{k}.metadata.json")))
      end
      rpm_list = modules.map{|k,v| v[:rpm]+"\n"}.join

      scanner = class_double('PuppetModuleRpmRepoScanner')
      ###allow(PuppetModuleRpmRepoScanner).to receive(:pupmod_rpm_list).and_return(rpm_list  + "\n")
      ###allow(instance_double(PuppetModuleRpmRepoScanner)).to receive(:pupmod_rpms).and_return(rpm_list  + "\n")

      scanner = PuppetModuleRpmRepoScanner.new
      allow(scanner).to receive(:`).with('rpm -qa').and_return(rpm_list  + "\n")
      modules.each do |k,mod|
        name = modules[k][:metadata]['name']
        allow(scanner).to receive(:`).with("rpm -ql #{mod[:rpm]}").and_return(mod[:rpm_ql])
        allow(scanner).to receive(:metadata).with("#{usr_mod_dir}/#{k}/metadata.json").and_return(modules[k][:metadata])
        allow(scanner).to receive(:local_git_repo_path).with(name).and_return("#{simp_git_dir}/#{name}.git")
      end

      allow(PuppetModuleRpmRepoScanner).to receive(:new).and_return(scanner)
    end
    it 'foo' do
      puts 'WAT'
      subject.run ['generate']
    end
  end
end
