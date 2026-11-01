# Windows System Repair Tool

A comprehensive batch script for diagnosing and repairing Windows system issues. This tool provides an interactive menu-driven interface to execute various Windows system maintenance and repair commands.

![Administrator Shield](https://img.shields.io/badge/requires-administrator-blue)
![Windows Support](https://img.shields.io/badge/platform-Windows-brightgreen)
![Batch Script](https://img.shields.io/badge/language-Batch-orange)

## 🔍 Features

- **Quick Status Check**: Rapid system image integrity verification
- **Detailed System Scan**: In-depth analysis of system image health
- **System Image Repair**: Automated repair of corrupted system files with Windows Update integration
- **System File Checker**: Comprehensive system file integrity verification and repair
- **Windows Update Repair**: Advanced troubleshooting for Windows Update issues including:
  - Service management
  - Component re-registration
  - Network reset
  - Driver cleanup
- **Sequential Repair Mode**: Optimized execution of core repair operations with automatic restart recommendation
- **Interactive Menu**: User-friendly interface with detailed help section

## 🚀 Getting Started

### Prerequisites

- Windows Operating System (Windows 10/11 recommended)
- Administrator privileges
- Active internet connection (for system file downloads during repairs)

### Installation

#### Quick start

Paste into **Windows PowerShell** and approve the administrator prompt:

```powershell
& { $p = "$env:TEMP\sys_repair.bat"; Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/Mohabdo21/Windows-Repair-Tool/main/sys_repair.bat' -OutFile $p -ErrorAction Stop; Start-Process -FilePath $p -Verb RunAs }
```

**Warning:** Downloads and runs code from `main` as administrator. Only run if you trust this repository.

#### Manual download

1. Download the `sys_repair.bat` file
2. Right-click the file and select "Run as administrator"

```batch
# Alternative: Launch from Command Prompt (Admin)
cd path/to/script
sys_repair.bat
```

## 💻 Usage

The script presents an interactive menu with the following options:

1. **Quick Status Check** (`DISM /CheckHealth`)
   - Fast verification of system image integrity
   - Recommended as first diagnostic step

2. **Detailed Scan** (`DISM /ScanHealth`)
   - Thorough system image analysis
   - May take several minutes to complete

3. **Repair System Image** (`DISM /RestoreHealth`)
   - Attempts to repair corrupted system files
   - Downloads replacement files if needed
   - Can take 15-30 minutes depending on system state

4. **System File Checker** (`sfc /scannow`)
   - Scans and repairs corrupted Windows system files
   - Recommended after DISM repairs

5. **System Update Repair**
   - Comprehensive Windows Update troubleshooting
   - Resets update-related services and components
   - Cleans up driver cache
   - Repairs network settings

6. **Run commands 2, 3, 4 Sequentially**
   - Executes the three core repair commands in optimal order:
     - **DISM /ScanHealth** (Detailed system scan)
     - **DISM /RestoreHealth** (Image repair)
     - **sfc /scannow** (System file verification)
   - **Always recommends a system restart** after completion to ensure repairs take effect
   - Does not include Windows Update repair operations

## ⚠️ Important Notes

- **Always backup important data** before running system repairs
- **Requires administrator privileges** to execute repairs
- **System restart is recommended** after running sequential repairs, regardless of individual command results
- Windows Update repairs may temporarily disable update services
- Internet connection required for downloading system files during repair
- The sequential repair mode follows Microsoft's recommended execution order for optimal results

## 🔧 Technical Details

The script performs the following technical operations:

### Core Repair Commands (Sequential Mode)

- **DISM ScanHealth**: Detects Windows image corruption
- **DISM RestoreHealth**: Repairs Windows component store using Windows Update
- **SFC scannow**: Verifies and repairs individual system files

### Windows Update Repair Operations

- Service management (stop/start) for:
  - Background Intelligent Transfer Service (BITS)
  - Windows Update Service
  - MSI Installer
  - Cryptographic Services
  - Application Identity Service
- Registry component re-registration
- Network stack reset
- Driver state management
- Windows component cleanup

## 📋 Command Execution Order

The sequential repair mode follows Microsoft's recommended order:

1. **DISM /ScanHealth** - Identifies corruption in the Windows image
2. **DISM /RestoreHealth** - Repairs the Windows component store
3. **sfc /scannow** - Repairs individual system files using the clean component store

This hierarchical approach ensures each tool can function optimally and repairs proceed from the foundational Windows image level down to individual system files.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔍 Troubleshooting

If you encounter issues:

1. Ensure you're running as administrator
2. Check internet connectivity for file downloads
3. Verify Windows Update service is accessible
4. Check system drive for sufficient space (at least 2GB free recommended)
5. Review logs in `%windir%\Logs\DISM\dism.log`
6. If sequential repairs don't resolve issues, try running individual commands separately
7. For persistent corruption, consider Windows in-place upgrade or system restore
