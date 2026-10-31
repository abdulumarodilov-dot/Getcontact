Pod::Spec.new do |s|
  s.name             = 'callerid_ios'
  s.version          = '0.1.0'
  s.summary          = "Call Directory extension bilan aloqa (Getcontact)"
  s.homepage         = 'https://github.com/abdulumarodilov-dot/Getcontact'
  s.license          = { :type => 'Private' }
  s.author           = { 'Getcontact' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.frameworks       = 'CallKit'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
