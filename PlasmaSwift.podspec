Pod::Spec.new do |s|
  s.name = 'PlasmaSwift'
  s.version = '0.2.0'
  s.summary = 'Plasma Client for Swift'
  s.homepage = 'https://github.com/openfresh/PlasmaSwift'
  s.license = { type: 'MIT', file: 'LICENSE' }
  s.author = { 'openfresh': 'valencia_dev@cyberagent.co.jp' }
  s.source = { git: 'https://github.com/openfresh/PlasmaSwift.git', tag: s.version.to_s }
  s.ios.deployment_target = '9.0'
  s.source_files = 'PlasmaSwift/**/*.{h,swift}'
  s.dependency 'SwiftGRPC', '>= 0.4.3'
end
