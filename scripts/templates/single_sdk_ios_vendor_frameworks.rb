# Download only the pinned SDK dependencies declared in vendor_frameworks.json.
# Flutter installs plugins as local CocoaPods, where prepare_command is skipped;
# resolve the frameworks before CocoaPods collects vendored_frameworks instead.
require 'digest'
require 'fileutils'
require 'json'
require 'tmpdir'

module FlutterRealtimeSdk
  module VendorFrameworks
    def self.install!(root)
      manifest = JSON.parse(File.read(File.join(root, 'vendor_frameworks.json')))
      destination = File.join(root, 'Frameworks')
      FileUtils.mkdir_p(destination)
      File.open(File.join(destination, '.install.lock'), 'w') do |lock|
        lock.flock(File::LOCK_EX)
        manifest.fetch('frameworks').each do |dependency|
          install_framework!(dependency, destination)
        end
      end
    end

    def self.install_framework!(dependency, destination)
      name = dependency.fetch('name')
      checksum = dependency.fetch('sha256')
      url = dependency.fetch('url')
      raise 'Invalid framework name' unless name.match?(/\A[A-Za-z][A-Za-z0-9_]*\z/)
      raise "Invalid checksum for #{name}" unless checksum.match?(/\A[0-9a-f]{64}\z/)
      raise "Insecure dependency URL for #{name}" unless url.start_with?('https://')

      framework = File.join(destination, "#{name}.xcframework")
      stamp = File.join(destination, ".#{name}.sha256")
      return if File.file?(File.join(framework, 'Info.plist')) &&
                File.file?(stamp) && File.read(stamp).strip == checksum

      Dir.mktmpdir(".#{name}-", destination) do |temporary|
        archive = cached_archive(url, checksum)
        unless archive
          if ENV['FLUTTER_REALTIME_SDK_IOS_OFFLINE'] == '1'
            raise "#{name}: pinned archive missing from local cache (offline mode)"
          end
          archive = File.join(temporary, 'sdk.zip')
          warn "[flutter_realtime_sdk] Fetching #{name} from #{url}"
          downloaded = system('/usr/bin/curl', '--fail', '--location', '--proto', '=https',
                              '--tlsv1.2', '--retry', '2', '--connect-timeout', '20',
                              '--max-time', '600', '--output', archive, url)
          raise "#{name}: official SDK download failed" unless downloaded
        end
        unless Digest::SHA256.file(archive).hexdigest == checksum
          raise "#{name}: SHA-256 mismatch; refusing to extract the SDK"
        end
        extracted = File.join(temporary, 'extracted')
        FileUtils.mkdir_p(extracted)
        unless system('/usr/bin/unzip', '-q', archive, '-d', extracted)
          raise "#{name}: SDK extraction failed"
        end
        candidates = Dir.glob(File.join(extracted, '**', "#{name}.xcframework")).select do |path|
          File.file?(File.join(path, 'Info.plist'))
        end
        unless candidates.length == 1
          raise "#{name}: official archive does not contain one expected XCFramework"
        end
        FileUtils.rm_rf(framework)
        FileUtils.mv(candidates.first, framework)
        File.write(stamp, "#{checksum}\n")
      end
    end

    def self.cached_archive(url, checksum)
      override = ENV['FLUTTER_REALTIME_SDK_IOS_ARCHIVE_CACHE']
      if override
        path = File.join(override, "#{checksum}.zip")
        return path if File.file?(path)
        return nil
      end
      # Reuse SwiftPM's existing, checksum-verified archive when available.
      key = url.gsub(/[^A-Za-z0-9]/, '_')
      path = File.join(Dir.home, 'Library', 'Caches', 'org.swift.swiftpm', 'artifacts', key)
      File.file?(path) ? path : nil
    end
  end
end
