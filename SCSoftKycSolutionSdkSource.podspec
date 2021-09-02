Pod::Spec.new do |spec|

  spec.name         = "SCSoftKycSolutionSdkSource"
  spec.version      = "0.1.0"
  spec.summary      = "SCSoftKycSolutionSdkSource summary"

  spec.homepage     = "https://github.com/samiozakyol/SCSoftKycSolutionSdkSource"
  spec.license      = "MIT"
  spec.author       = { "Sami Ozakyol" => "samiozakyol@gmail.com" }
  spec.platform 	   = :ios
  spec.ios.deployment_target = "12.0"
  spec.source       = { :git => 'https://github.com/samiozakyol/SCSoftKycSolutionSdkSource.git', :tag => spec.version }
  
  spec.source_files = "SCSoftKycSolutionSdkSource/**/*.{swift}"
  spec.resources    = "SCSoftKycSolutionSdkSource/Supporting Files/tessdata", "SCSoftKycSolutionSdkSource/Supporting Files/SdkAssets.xcassets"

  spec.swift_version = "5.0"

  spec.dependency "QKMRZParser", '1.0.1'
  spec.dependency "NFCPassportReader" , '1.1.4'
  spec.dependency "SwiftyTesseract", '3.1.3'
  spec.dependency "JitsiMeetSDK" , '3.3.0'

  spec.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  spec.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }

end
