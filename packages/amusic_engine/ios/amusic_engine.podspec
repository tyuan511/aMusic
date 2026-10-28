Pod::Spec.new do |s|
  s.name             = 'amusic_engine'
  s.version          = '0.1.0'
  s.summary          = 'aMusic audio engine (Rust).'
  s.description      = 'Decode, equalizer, effects, limiter and output, built from ../rust.'
  s.homepage         = 'https://github.com/'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'aMusic' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'

  s.frameworks = 'AudioToolbox', 'AVFoundation', 'CoreAudio', 'Foundation', 'CoreFoundation'
  s.libraries  = 'iconv', 'objc'

  # Build the Rust static library before this pod compiles, then force the
  # linker to keep every exported symbol: Dart looks them up with dlsym, so
  # nothing in native code references them.
  s.script_phase = {
    :name => 'Build Rust engine',
    :script => 'sh "${PODS_TARGET_SRCROOT}/build_rust.sh"',
    :execution_position => :before_compile,
    :always_out_of_date => '1',
    :output_files => ['${BUILT_PRODUCTS_DIR}/libamusic_engine.a'],
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '-force_load "${BUILT_PRODUCTS_DIR}/libamusic_engine.a"',
  }
end
