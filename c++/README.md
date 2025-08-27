# awsctx.cpp

`awsctx.cpp` offers **robust and accurate shell detection** (CMD or PowerShell) comparing to the logic used in batch file (`awsctx.cmd`), particularly in environments where nested shells are common. It detects the running shell on Windows and pass it as a boolean value to `build-init.cmd` to setup aws/s3 profile in shell envirnoment. 

`build-init.cmd` is basically the same `awsctx.cmd` file with below differences:

- Shell detection logic is not used as it is handled by `awsctx.cpp`
- Command-Prompt init file `cmd-init.cmd` generation is added to `build-init.cmd` which is not necessary in `awsctx.cmd`

Therefore, trade-offs of using `awsctx.cpp` as the launcher of the script comparing to using the stand-alone script `awsctx.cmd` are:

- With `awsctx.cmd`, you get a less reliable shell detection when you are running in nested shells envirnoment (e.g. if CMD was launched from PowerShell). However, all necessary envirnoment variables are automatically exported on Command-Prompt while on PowerShell, you need to source it manually using generated file `ps-init.ps1`.

- With `awsctx.cpp`, you get a **robust and accurate shell detection** — even in nested shells environment. But, for exporting envirnoment variables, you need to source the init file of the running shell on both Command-Prompt and PowerShell.

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

4. Add `awsctx` directory to system `PATH`  
 
5. Place other files in the appropriate locations:
```batch
%USERPROFILE%\.aws\config
%USERPROFILE%\.aws\credentials
%USERPROFILE%\.aws\certificate.pem  ::if applicable
```
6. Install required tools via Chocolatey:
```batch
~$ choco install fzf aws
```

7. Optional: other available S3-compatible CLI clients:
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