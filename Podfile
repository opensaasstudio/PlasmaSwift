source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '9.0'

use_frameworks!

target 'PlasmaSwift' do
  pod '!ProtoCompiler-gRPCPlugin', '1.9.1'
end

pre_install do
  grpc_swift_version='0.4.1'

  system <<-CMD
  git clone --branch #{grpc_swift_version} 'https://github.com/grpc/grpc-swift'
  cd grpc-swift
  make
  cd ..
  CMD
end

post_install do
  pods_root = "Pods"
  protoc_dir = "#{pods_root}/!ProtoCompiler"
  protoc = "#{protoc_dir}/protoc"
  plugin = "grpc-swift/.build/debug"
  proto_dir = "proto"

  system <<-CMD
"#{protoc}" \\
  --plugin="#{plugin}" \\
  --swift_opt=Visibility=Public \\
  --swift_out=. \\
  --swiftgrpc_out=Visibility=Public,Client=true,Server=false:. \\
  -I #{proto_dir} \\
  -I #{protoc_dir} \\
  #{proto_dir}/stream.proto
CMD
end
