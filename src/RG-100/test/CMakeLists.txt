
include(FetchContent)

FetchContent_Declare(
    elf2hex
    GIT_REPOSITORY https://github.com/sifive/elf2hex.git
    GIT_TAG        "v20.08.00.00"
)

FetchContent_MakeAvailable(elf2hex)
