// File: awsctx.cpp
// Purpose: detects the running shell on windows (cmd or powershell) and pass it as a boolean value to 'build-init.cmd' to setup aws/s3 profile in shell envirnoment
// Author: Hamed Davodi
// Date: 2025-08-21

#define UNICODE
#include <windows.h>
#include <tlhelp32.h>
#include <tchar.h>
#include <iostream>
#include <string>
#include <filesystem>


namespace fs = std::filesystem;

// ANSI color codes for styling
const std::wstring RESET  = L"\x1b[0m";
const std::wstring BOLD   = L"\x1b[1m";
const std::wstring CYAN   = L"\x1b[36m";
const std::wstring GRAY   = L"\x1b[90m";
const std::wstring YELLOW = L"\x1b[33m";


// Print error and exit
void ExitWithError(const std::wstring& message) {
    std::wcerr << CYAN << L"[awsctx] "
               << RESET << GRAY << L"ERROR:"
               << RESET << L" " << message << L"\n";
    ExitProcess(EXIT_FAILURE);
}

// Launch external script
int LaunchScript(const std::wstring& commandLine) {
    STARTUPINFOW si{};
    PROCESS_INFORMATION pi{};
    si.cb = sizeof(si);

    if (!CreateProcessW(
            nullptr,
            const_cast<LPWSTR>(commandLine.c_str()),
            nullptr, nullptr, FALSE,
            0, nullptr, nullptr, &si, &pi)) {
        ExitWithError(GRAY + L"CreateProcessW failed -> " + YELLOW + commandLine);
    }

    WaitForSingleObject(pi.hProcess, INFINITE);

    DWORD exitCode = 0;
    GetExitCodeProcess(pi.hProcess, &exitCode);

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    return static_cast<int>(exitCode);
}


// Get parent PID
DWORD GetParentPid(DWORD pid) {
    DWORD ppid = 0;
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return 0;

    PROCESSENTRY32W pe{};
    pe.dwSize = sizeof(pe);

    if (Process32FirstW(snap, &pe)) {
        do {
            if (pe.th32ProcessID == pid) {
                ppid = pe.th32ParentProcessID;
                break;
            }
        } while (Process32NextW(snap, &pe));
    }

    CloseHandle(snap);
    return ppid;
}

// Get process name from PID
std::wstring GetProcessName(DWORD pid) {
    std::wstring name;

    // Get a list of all running processes
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return L"";

    PROCESSENTRY32W pe{};
    pe.dwSize = sizeof(pe);

   // Iterate over each process to find matching pid
    if (Process32FirstW(snap, &pe)) {
        do {
            if (pe.th32ProcessID == pid) {
                name = pe.szExeFile;
                break;
            }
        } while (Process32NextW(snap, &pe));
    }

    CloseHandle(snap);

    // Convert process name to lowercase
    for (auto& c : name) c = towlower(c); 
    return name;
}

// Determine if current shell is PowerShell
bool IsRunningInPowerShell() {
    DWORD pid = GetCurrentProcessId(); 
    DWORD parentPid = GetParentPid(pid);
    std::wstring parentName = GetProcessName(parentPid);

    return (parentName == L"powershell.exe" || parentName == L"pwsh.exe");
}



int wmain() {
    
    // Determine root directory of awsctx.exe to find build script
    wchar_t exePath[MAX_PATH];
    GetModuleFileNameW(nullptr, exePath, MAX_PATH);
    fs::path rootDir = fs::path(exePath).parent_path();
    fs::path scriptDir = rootDir / L"script";
    fs::path buildScr = scriptDir / L"build-init.cmd";

    // Check if build script exists
    if (!fs::exists(buildScr)) {
        ExitWithError(GRAY + L"missing script -> " + YELLOW + buildScr.wstring());
    }
	
    // Get the running shell value and pass it to a string  
    bool isPowershell = IsRunningInPowerShell();
    std::wstring boolStr = isPowershell ? L"1" : L"0";

    // Execute build script with argument boolStr
    std::wstring commandLine = L"cmd /c \"" + buildScr.wstring() + L" " + boolStr + L"\"";
    int exitCode = LaunchScript(commandLine);

    // Print messages based on exit code of build script
	switch (exitCode) {
    case 1:
        std::wcout << CYAN << L"[awsctx] " << RESET << GRAY << L"No Profile Selected." << RESET << L"\n";
        break;
    case 2:
        std::wcerr << CYAN << L"[awsctx] " << RESET << GRAY << L"ERROR: endpoint_url not found." << RESET << L"\n";
		break;
    case 3:
        std::wcerr << CYAN << L"[awsctx] " << RESET << GRAY << L"ERROR: aws_access_key_id not found." << RESET << L"\n";
		break;
	case 4:
        std::wcerr << CYAN << L"[awsctx] " << RESET << GRAY << L"ERROR: aws_secret_access_key not found." << RESET << L"\n";
		break;
	case 5:
        std::wcerr << CYAN << L"[awsctx] " << RESET << GRAY << L"ERROR: region not found." << RESET << L"\n";
       
	}

	return 0;
	

}