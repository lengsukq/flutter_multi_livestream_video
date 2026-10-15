# Called explicitly from the application's post_integrate hook. This does not
# replace its own hooks or alter any vendor SDK's files or dependency versions.
module FlutterRealtimeSdk
  module PodfileIntegration
    def self.deduplicate_agora_frameworks!(installer)
      ios = installer.config.installation_root.to_s
      package = File.join(ios, 'Flutter', 'ephemeral', 'Packages',
                          'FlutterGeneratedPluginSwiftPackage', 'Package.swift')
      # Chat alone needs its CocoaPods aosl. Remove its embed only when RTC's
      # SwiftPM product supplies aosl to this same app.
      return unless File.file?(package) && File.read(package).include?('name: "agora-rtc-engine"')

      support = File.join(installer.sandbox.root.to_s, 'Target Support Files')
      Dir.glob(File.join(support, 'Pods-*')).each do |target|
        scripts = Dir.glob(File.join(target, '*-frameworks.sh'))
        scripts.each do |script|
          next unless File.read(script).include?('/ShengwangInfra_iOS/aosl.framework')

          rewrite_without(script) { |line| line.include?('/ShengwangInfra_iOS/aosl.framework') }
          Dir.glob(File.join(target, '*-frameworks-*-input-files.xcfilelist')).each do |path|
            rewrite_without(path) { |line| line.include?('/ShengwangInfra_iOS/aosl.framework/') }
          end
          Dir.glob(File.join(target, '*-frameworks-*-output-files.xcfilelist')).each do |path|
            rewrite_without(path) do |line|
              line.strip == '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/aosl.framework'
            end
          end
        end
      end
    end

    def self.rewrite_without(path)
      original = File.read(path)
      modified = original.lines.reject { |line| yield(line) }.join
      File.write(path, modified) if modified != original
    end
  end
end
