Pod::Spec.new do |s|
  s.name         = 'VKActivity'
  s.version      = '1.0.1'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.summary      = 'An UIAvtivity subclass for sharing on vk.com'
  s.homepage     = 'https://github.com/Antol/VKActivity'
  s.authors      = { 'DENIVIP Group' => 'https://github.com/denivip', 'Antol Peshkov' => 'http://github.com/Antol' }
  s.source       = { :git => 'https://github.com/Antol/VKActivity.git', :tag => s.version.to_s }

  s.source_files = 'VKActivity/*.{h,m}'
  s.frameworks   = 'Foundation', 'UIKit'
  s.requires_arc = true
  s.platform     = :ios, '6.0'

  s.dependency 'VK-ios-sdk'
  s.dependency 'REComposeViewController'
end
