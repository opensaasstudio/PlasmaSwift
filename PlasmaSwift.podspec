#
# Be sure to run `pod lib lint PlasmaSwift.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PlasmaSwift'
  s.version          = '0.0.4'
  s.summary          = 'A short description of PlasmaSwift.'

  s.description      = <<-DESC
Plasma Client for Swift.
                       DESC

  s.homepage         = 'https://github.com/openfresh/PlasmaSwift'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'FRESH!' => 'valencia_dev@cyberagent.co.jp' }
  s.source           = { :git => 'https://github.com/openfresh/PlasmaSwift.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'

  s.source_files = 'PlasmaSwift/**/*.{h,swift}'

  s.dependency "!ProtoCompiler-gRPCPlugin", "~> 1.3.0"

  pods_root = 'Pods'
  protoc_dir = "#{pods_root}/!ProtoCompiler"
  protoc = "#{protoc_dir}/protoc"
  plugin = "#{pods_root}/!ProtoCompiler-gRPCPlugin/grpc_objective_c_plugin"
  # avoid pod spec error
  #s.prepare_command = <<-CMD
    ##{protoc} \
        #--plugin=protoc-gen-grpc=#{plugin} \
        #--objc_out=. \
        #--grpc_out=. \
        #-I ./proto \
        #-I #{protoc_dir} \
        #./proto/stream.proto
  #CMD

  s.subspec 'Messages' do |ms|
    ms.source_files = '*.pbobjc.{h,m}'
    ms.header_mappings_dir = '.'
    ms.requires_arc = false
    ms.dependency 'Protobuf'
    # This is needed by all pods that depend on Protobuf:
    ms.pod_target_xcconfig = {
      'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS=1',
      'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    }
  end

  s.subspec 'Services' do |ss|
    ss.source_files = '*.pbrpc.{h,m}'
    ss.header_mappings_dir = '.'
    ss.requires_arc = true
    ss.dependency 'gRPC-ProtoRPC'
    ss.dependency "#{s.name}/Messages"
  end

end
