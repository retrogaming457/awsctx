# awsctx.cpp

`awsctx.cpp` offers **robust and accurate shell detection** (CMD or PowerShell) comparing to the logic used in batch file (`awsctx.cmd`), particularly in environments where nested shells are common. It detects the running shell on Windows and pass it as a boolean value to `build-init.cmd` to setup aws/s3 profile in shell envirnoment.

## Compilation and Setup

1. Download or Clone the repository
2. Rename `c++` directory to `awsctx` if necessary
3. Compile source code (**C++17** or later): 
  
Using `cl` (MSVC):

```batch
cl /std:c++17 /EHsc C:\Library\awsctx\source\awsctx.cpp FoC:\Library\awsctx\awsctx.obj /FeC:\Library\awsctx\awsctx.exe
```

Using `g++` :
```batch
g++ -std=c++17 -c -o C:\Library\awsctx\awsctx.o C:\Library\awsctx\source\awsctx.cpp
g++ -o C:\Library\awsctx\awsctx.exe C:\Library\awsctx\awsctx.o
```

1. Add `awsctx` directory to system `PATH`  
 
2. Place other files in the appropriate locations:
```batch
%USERPROFILE%\.aws\config
%USERPROFILE%\.aws\credentials
%USERPROFILE%\.aws\certificate.pem  ::if applicable
```
1. Install required tools via Chocolatey:
```batch
~$ choco install fzf aws
```

1. Optional: other available S3-compatible CLI clients:
```batch
~$ pip install s3cmd
~$ pip install s4cmd
~$ scoop install s5cmd
```

### Files Structure
```
awsctx/
├── script/
│   └── build-init.cmd
│   └── cmd-init.cmd 
│   └── ps-init.ps1
├── source/
│   └── awsctx.cpp
├── awsctx.exe (after build)
└── README.md
```
- `build-init.cmd` script is required by `awsctx.exe`. 
- `cmd-init.cmd` and `ps-init.ps1` are created/overwritten by `build-init.cmd` 