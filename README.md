# RISC-V

# CMake Usage Notes
Due to the inability for bsc to handle parallel build jobs on the same file set, CMake needs to be set up to only use a single build thread.   This is done inside settings.json if building inside Visual Studio too; otherwise the appropriate setting for the backend build environment should be used (e.g. -j 1).
