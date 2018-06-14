source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'

use_frameworks!

target 'PlasmaSwift' do
  pod '!ProtoCompiler-gRPCPlugin', '1.9.1'
end

post_install do
  pods_root = "Pods"
  protoc_dir = "#{pods_root}/!ProtoCompiler"
  protoc = "#{protoc_dir}/protoc"
  plugin = "#{pods_root}/!ProtoCompiler-gRPCPlugin/grpc_objective_c_plugin"
  proto_dir = "proto"

  system <<-CMD
"#{protoc}" \\
  --plugin=protoc-gen-grpc="#{plugin}" \\
  --objc_out=. \\
  --grpc_out=. \\
  -I #{proto_dir} \\
  -I #{protoc_dir} \\
  #{proto_dir}/stream.proto
CMD
end
