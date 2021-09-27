Pod::Spec.new do |spec|

  spec.name         = "SCSoftKycSolutionSdkSource"
  spec.version      = "0.1.6"
  spec.summary      = "SCSoftKycSolutionSdkSource summary"

  spec.homepage     = "https://github.com/samiozakyol/SCSoftKycSolutionSdkSource"
  spec.license      = "MIT"
  spec.author       = { "Sami Ozakyol" => "samiozakyol@gmail.com" }
  spec.platform 	   = :ios
  spec.ios.deployment_target = "11.0"
  spec.source       = { :git => 'https://github.com/samiozakyol/SCSoftKycSolutionSdkSource.git', :tag => spec.version }
  
  spec.source_files = "SCSoftKycSolutionSdkSource/**/*.{swift}"
  spec.resources    = "SCSoftKycSolutionSdkSource/Supporting Files/tessdata", "SCSoftKycSolutionSdkSource/Supporting Files/SdkAssets.xcassets"

  spec.swift_version = "5.0"

  spec.dependency "OpenSSL-Universal", '1.1.180'
  spec.dependency "SwiftyTesseract", '3.1.3'
  spec.dependency "JitsiMeetSDK" , '3.3.0'

  spec.xcconfig          = { 'OTHER_LDFLAGS' => '-weak_framework CryptoKit -weak_framework CoreNFC -weak_framework CryptoTokenKit' }

  spec.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  spec.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }

end
