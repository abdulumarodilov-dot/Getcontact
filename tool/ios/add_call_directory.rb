#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Xcode loyihasiga Call Directory extension'ni qo'shadi (Jizzax caller ID).
#
#   ruby tool/ios/add_call_directory.rb
#
# Loyiha ildizidan ishga tushiriladi, `flutter create` va `pod install`
# dan KEYIN. Qayta ishga tushirilsa hech narsani buzmaydi (idempotent).
#
# Nima qiladi:
#   1. tool/ios/CallDirectory/* → ios/CallDirectory/ ga nusxalaydi
#   2. "CallDirectory" app-extension target'ini yaratadi (CallKit bilan)
#   3. Uni Runner'ga dependency va "Embed Foundation Extensions" sifatida
#      qo'shadi ("Thin Binary" skriptidan OLDIN — aks holda Xcode
#      "Cycle inside Runner" xatosini beradi)
#   4. Ikkala target uchun App Group entitlements faylini yozadi

require 'fileutils'
require 'xcodeproj'

ROOT = File.expand_path('../..', __dir__)
IOS = File.join(ROOT, 'ios')
PROJ = File.join(IOS, 'Runner.xcodeproj')
SRC = File.join(ROOT, 'tool', 'ios', 'CallDirectory')
DST = File.join(IOS, 'CallDirectory')
EXT = 'CallDirectory'
MIN_IOS = '13.0'

abort "❌ #{PROJ} topilmadi" unless Dir.exist?(PROJ)

# ── Versiya pubspec.yaml dan (extension ilova bilan bir xil bo'lishi kerak)
pubspec = File.read(File.join(ROOT, 'pubspec.yaml'))
m = pubspec.match(/^version:\s*([0-9.]+)(?:\+([0-9]+))?/)
marketing = m ? m[1] : '1.0.0'
build_no = m && m[2] ? m[2] : '1'

project = Xcodeproj::Project.open(PROJ)
runner = project.targets.find { |t| t.name == 'Runner' }
abort '❌ Runner target topilmadi' unless runner

bundle_id = runner.build_configurations
                  .map { |c| c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] }
                  .compact.first
abort '❌ Runner PRODUCT_BUNDLE_IDENTIFIER topilmadi' unless bundle_id
group_id = "group.#{bundle_id}"
puts "→ Bundle ID: #{bundle_id}  |  App Group: #{group_id}"

# ── 1. Fayllar ────────────────────────────────────────────
FileUtils.mkdir_p(DST)
%w[CallDirectoryHandler.swift Info.plist].each do |f|
  FileUtils.cp(File.join(SRC, f), File.join(DST, f))
end

def entitlements(group_id)
  <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    	<key>com.apple.security.application-groups</key>
    	<array>
    		<string>#{group_id}</string>
    	</array>
    </dict>
    </plist>
  XML
end
File.write(File.join(DST, "#{EXT}.entitlements"), entitlements(group_id))
File.write(File.join(IOS, 'Runner', 'Runner.entitlements'), entitlements(group_id))

# Runner entitlements
runner.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

# ── 2. Target ─────────────────────────────────────────────
if project.targets.any? { |t| t.name == EXT }
  puts "→ #{EXT} target allaqachon bor — faqat fayllar yangilandi"
  project.save
  exit 0
end

ext = project.new_target(:app_extension, EXT, :ios, MIN_IOS, nil, :swift)

# Loyihadagi har bir konfiguratsiya (Debug/Release/Profile) target'da ham
# bo'lishi kerak, aks holda "flutter build" Profile'da yiqiladi.
existing = ext.build_configurations.map(&:name)
project.build_configurations.each do |pc|
  next if existing.include?(pc.name)
  base = ext.build_configurations.find { |c| c.name == 'Release' }
  nc = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  nc.name = pc.name
  nc.build_settings = base.build_settings.dup
  ext.build_configuration_list.build_configurations << nc
end

ext.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = "#{bundle_id}.#{EXT}"
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = "#{EXT}/Info.plist"
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['CODE_SIGN_ENTITLEMENTS'] = "#{EXT}/#{EXT}.entitlements"
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['SWIFT_VERSION'] = '5.0'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = MIN_IOS
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['SKIP_INSTALL'] = 'YES'
  s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  s['ENABLE_BITCODE'] = 'NO'
  s['MARKETING_VERSION'] = marketing
  s['CURRENT_PROJECT_VERSION'] = build_no
  s['LD_RUNPATH_SEARCH_PATHS'] = [
    '$(inherited)',
    '@executable_path/Frameworks',
    '@executable_path/../../Frameworks'
  ]
end

# Fayl havolalari (guruh yo'li "CallDirectory" — ios/ ga nisbatan)
grp = project.main_group.children.find { |g| g.display_name == EXT } ||
      project.main_group.new_group(EXT, EXT)
swift_ref = grp.files.find { |f| f.path == 'CallDirectoryHandler.swift' } ||
            grp.new_reference('CallDirectoryHandler.swift')
%w[Info.plist].push("#{EXT}.entitlements").each do |f|
  grp.new_reference(f) unless grp.files.any? { |r| r.path == f }
end
ext.add_file_references([swift_ref])
ext.add_system_framework('CallKit')

# ── 3. Runner'ga ulash ────────────────────────────────────
runner.add_dependency(ext)

embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
bf = embed.add_file_reference(ext.product_reference, true)
bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# "Thin Binary" (va boshqa Flutter skriptlari) dan oldinga qo'yamiz
runner.build_phases.delete(embed)
idx = runner.build_phases.index do |p|
  p.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase) &&
    p.name.to_s.include?('Thin Binary')
end
idx ||= runner.build_phases.length
runner.build_phases.insert(idx, embed)

project.save

puts "✅ #{EXT} extension qo'shildi (#{bundle_id}.#{EXT}, v#{marketing}+#{build_no})"
puts '   Runner build phases:'
runner.build_phases.each { |p| puts "     - #{p.display_name}" }
