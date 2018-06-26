source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '9.0'

use_frameworks!

target 'PlasmaSwift' do
  pod '!ProtoCompiler-gRPCPlugin', '1.12.0'
end

pre_install do
  grpc_swift_version='0.4.3'

  # system <<-CMD
  # git clone --branch #{grpc_swift_version} 'https://github.com/grpc/grpc-swift'
  # cd grpc-swift
  # make
  # cd ..
  # CMD
end

post_install do
  pods_root = "Pods"
  protoc_dir = "#{pods_root}/!ProtoCompiler"
  protoc = "#{protoc_dir}/protoc"
  plugin = "./grpc-swift"
  proto_dir = "proto"
  destination_dir = "./PlasmaSwift"

  system <<-CMD
"#{protoc}" #{proto_dir}/stream.proto \\
  --swift_opt=Visibility=Public \\
  --swift_out=#{destination_dir} \\
  --swiftgrpc_out=Visibility=Public,Client=true,Server=false:"#{destination_dir}" \\
  -I #{proto_dir} \\
  -I #{protoc_dir} \\
CMD
end
