module fpm_compiler

implicit none

type :: compiler_t
contains
    procedure :: enumerate_libraries
end type compiler_t

contains

function enumerate_libraries(self, libs) result(r)
    class(compiler_t), intent(in) :: self
    integer, intent(in) :: libs(:)
    character(len=:), allocatable :: r
end function enumerate_libraries

end module fpm_compiler

program modules_38
use fpm_compiler

type(compiler_t) :: compiler_arg
integer:: libs_arg(4)
print *, compiler_arg%enumerate_libraries( libs_arg)

end program
