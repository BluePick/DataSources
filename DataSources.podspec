Pod::Spec.new do |s|
  s.name = 'DataSources'
  s.version = '0.1.0'
  s.summary = 'data-driven DataSources'
  s.homepage = 'https://github.com/muukii/DataSources'
  s.description = 'Data driven DataSources'

  s.license =  { :type => 'MIT' }
  s.author = { 'muukii' => 'm@muukii.me' }
  s.social_media_url = 'https://twitter.com/muukii0803'
  s.source = { :git => 'https://github.com/muukii/DataSources.git', :tag => s.version.to_s }

  s.subspec 'Diff' do |ds|
    ds.source_files = 'Source/Diff/**/*.swift'
    ds.module_name = 'Diff'
  end

  s.subspec 'Default' do |cs|
    cs.dependency 'DataSources/Diff'
    cs.source_files = 'Source/DataSources/**/*.swift'
  end

  s.default_subspec = 'Default'
  s.requires_arc = true
  s.ios.deployment_target = '9.0'
  s.ios.frameworks = 'UIKit'
end
