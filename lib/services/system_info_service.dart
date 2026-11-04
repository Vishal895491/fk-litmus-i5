import 'dart:io';
import 'dart:convert';

class SystemInfoService {
  static Future<Map<String, dynamic>> fetch() async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows required');
    }

    const script = r'''
$ErrorActionPreference = "SilentlyContinue"

$computer = Get-CimInstance Win32_ComputerSystem
$processor = Get-CimInstance Win32_Processor | Select-Object -First 1
$bios = Get-CimInstance Win32_BIOS
$ram = Get-CimInstance Win32_PhysicalMemory
$disks = Get-CimInstance Win32_DiskDrive
$battery = Get-CimInstance Win32_Battery

$wifi = Get-NetAdapter -Physical |
  Where-Object {
    $_.InterfaceDescription -match 'Wi-Fi|Wireless|802.11'
  }

$bluetooth = Get-PnpDevice -Class Bluetooth |
  Where-Object { $_.Status -eq 'OK' }

$static = Get-CimInstance -Namespace root\wmi `
  -ClassName BatteryStaticData |
  Select-Object -First 1

$full = Get-CimInstance -Namespace root\wmi `
  -ClassName BatteryFullChargedCapacity |
  Select-Object -First 1

$ramBytes = ($ram | Measure-Object -Property Capacity -Sum).Sum
$diskBytes = ($disks | Measure-Object -Property Size -Sum).Sum

$health = $null
if ($static.DesignedCapacity -gt 0 -and
    $full.FullChargedCapacity -gt 0) {
  $health = [math]::Round(
    ($full.FullChargedCapacity / $static.DesignedCapacity) * 100, 1
  )
}

$result = [ordered]@{
  brand = $computer.Manufacturer
  model = $computer.Model
  serial = $bios.SerialNumber
  processorActual = $processor.Name
  ramGB = if ($ramBytes) {
    [math]::Round($ramBytes / 1GB, 1)
  } else { $null }
  storageGB = if ($diskBytes) {
    [math]::Round($diskBytes / 1GB, 1)
  } else { $null }
  wifi = [bool]($wifi)
  bluetooth = [bool]($bluetooth)
  batteryPercentage = if ($battery) {
    $battery[0].EstimatedChargeRemaining
  } else { $null }
  designCapacity = if ($static.DesignedCapacity) {
    $static.DesignedCapacity
  } else { $null }
  fullChargeCapacity = if ($full.FullChargedCapacity) {
    $full.FullChargedCapacity
  } else { $null }
  batteryHealth = $health
}

$result | ConvertTo-Json -Compress -Depth 4
''';

    final result = await Process.run(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        script,
      ],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      throw Exception('Hardware detection failed: ${result.stderr}');
    }

    final output = result.stdout.toString().trim();
    if (output.isEmpty) {
      throw Exception('Windows returned no hardware information');
    }

    return Map<String, dynamic>.from(jsonDecode(output));
  }
}