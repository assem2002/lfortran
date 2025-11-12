# LLVMFinalize Class
## Brief
- Finalizes symbol-table's variables.
- It's used right before returning from an ASR construct (program, function, block, etc.)
## Design Flow
Global variables aren't finalized; They live till program ends anyway so we don't care much about them.
The class has finalizers for each and every type; Each one is only responsible of freeing and finalizing its own internals.
There are 2 general finalizer types that handles the job -- `finalize_type` and `finalize_TypeSpecific`
#### Main Finalizers
- `finalize_type(ptr, t)` :
    It's a finalizer that gets a ptr to the type you're finalizing (integer, array, struct, list, etc..). It's responsible of finalizing the **shell** of the type not the internals of it.
    If the **shell** is owned by some containing type and that container has got some rules over finalizing that **shell**, it's completely the responsibility of the container and not the responsibility of `finalize_type()` (see arrays and lists).

    **Example**: `type(t), allocatable :: n`

    `finalize_type()` It finalizes the **shell** of the type. it's responsible of freeing the type based on how we actually do allocate it,
    so for allocatable-structs we happen to declare it as `{type1, type2, ..}*` in LLVM IR and when we allocate it we happen to 
    heap allocate the size of the struct and store it in that pointer. That makes alloctable-structs type on its own a type that needs
    a finalization, the internals of the struct is the responsibility of `finalize_struct()` which is a type-specific finalizers.
- `finalize_TypeSpecific()`
    This a general representation for the following :

    `finalize_scalars()`, `finalize_struct()`, `finalize_string()`,`finalize_array()`,
    `finalize_list()`, `finalize_set()` ,`finalize_dict()` ,`finalize_tuple()`, `finalize_union()`

    Each one of those is responsible of finalizing the internals of the type it's named after.

    **Example**: `type(t), allocatable :: n`

    `finalize_struct()` once works on that `t` type, it will loop on each and every variable (struct member) and free it using both `finalize_specifictype()` and `finalize_type()` that we just discussed above. Notice `finalize_struct` used `finalize_type` as it's okay with how `finalize_type` finalizes the shells 

## Examples

#### `type(t), alloatable :: t_arr(:)`
- `finalize_array()` --> Finalizes internals elements and other info (if any is heap allocated).
- `finalize_array()` --> Calls utility `finalize_array_data()` to free elements as different array types require different handling.
- `finalize_array_data()` --> Loops on the array size to get each and every structtype `t` allocated.
- `finalize_array_data()` --> calls `finalize_struct()` on each element. Notice `finalize_type()` not called as array a container that's responsible of the contained types. It's responsible of freeing the **shell**s of the contained types (in array's case all structs are just consecutively allocated and freed all at once).  
- `finalize_struct()` --> loops on each and every element attempting to finalize the **shell**s of the contained types through `finalize_type()` + each contained type will also get finalized by its own finalizer (notice we could come across another array which will make us go through these steps again recursively).
- back to `finalize_consecutive_array_ptr()` --> this is responsible of freeing consecutively allocated memory of the array (**shell**s of the contained types in the array).
- back to `finalize_type()` --> finalizes the **shell** of the array `t_arr` (if needed).