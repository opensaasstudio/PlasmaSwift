Pod::Spec.new do |s|
  s.name = 'PlasmaSwift'
  s.version = '0.0.5'
  s.summary = 'Plasma Client for Swift'
  s.homepage = 'https://github.com/openfresh/PlasmaSwift'
  s.license = { type: 'MIT', file: 'LICENSE' }
  s.author = { 'openfresh': 'valencia_dev@cyberagent.co.jp' }
  s.source = { git: 'https://github.com/openfresh/PlasmaSwift.git', tag: s.version.to_s }
  s.ios.deployment_target = '8.0'
  s.source_files = 'PlasmaSwift/**/*.{h,swift}'

  s.subspec 'Messages' do |ms|
    ms.source_files = '*.pbobjc.{h,m}'
    ms.header_mappings_dir = '.'
    ms.requires_arc = false
    ms.dependency 'Protobuf', '~> 3.5.0'
    # This is needed by all pods that depend on Protobuf:
    ms.pod_target_xcconfig = {
      'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS=1'
    }
  end

  s.subspec 'Services' do |ss|
    ss.source_files = '*.pbrpc.{h,m}'
    ss.header_mappings_dir = '.'
    ss.requires_arc = true
    ss.dependency 'gRPC-ProtoRPC', '~> 1.9.1'
    ss.dependency "#{s.name}/Messages"
  end

  s.pod_target_xcconfig = {
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
  }
end