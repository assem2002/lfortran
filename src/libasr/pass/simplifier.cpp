#include <libasr/asr.h>
#include <libasr/containers.h>
#include <libasr/asr_utils.h>
#include <libasr/pass/simplifier.h>

#include <vector>
#include <utility>

namespace LCompilers {

ASR::expr_t* create_temporary_variable_for_array(Allocator& al,
    ASR::expr_t* value, SymbolTable* scope, std::string name_hint) {
    ASR::ttype_t* value_type = ASRUtils::expr_type(value);
    LCOMPILERS_ASSERT(ASRUtils::is_array(value_type));

    /* Figure out the type of the temporary array variable */
    ASR::dimension_t* value_m_dims = nullptr;
    size_t value_n_dims = ASRUtils::extract_dimensions_from_ttype(value_type, value_m_dims);
    bool is_fixed_sized_array = ASRUtils::is_fixed_size_array(value_type);
    bool is_size_only_dependent_on_arguments = ASRUtils::is_dimension_dependent_only_on_arguments(
        value_m_dims, value_n_dims);
    bool is_allocatable = ASRUtils::is_allocatable(value_type);
    ASR::ttype_t* var_type = nullptr;
    if( is_fixed_sized_array || is_size_only_dependent_on_arguments || is_allocatable ) {
        var_type = value_type;
    } else {
        Vec<ASR::dimension_t> empty_dims; empty_dims.reserve(al, value_n_dims);
        for( size_t i = 0; i < value_n_dims; i++ ) {
            ASR::dimension_t empty_dim;
            Location loc; loc.first = 1, loc.last = 1;
            empty_dim.loc = loc;
            empty_dim.m_length = nullptr;
            empty_dim.m_start = nullptr;
            empty_dims.push_back(al, empty_dim);
        }
        var_type = ASRUtils::make_Array_t_util(al, value_type->base.loc,
            ASRUtils::extract_type(value_type), empty_dims.p, empty_dims.size());
        var_type = ASRUtils::TYPE(ASR::make_Allocatable_t(al, var_type->base.loc, var_type));
    }

    std::string var_name = scope->get_unique_name("__libasr_created_" + name_hint);
    ASR::symbol_t* temporary_variable = ASR::down_cast<ASR::symbol_t>(ASR::make_Variable_t(
        al, value->base.loc, scope, s2c(al, var_name), nullptr, 0, ASR::intentType::Local,
        nullptr, nullptr, ASR::storage_typeType::Default, var_type, nullptr, ASR::abiType::Source,
        ASR::accessType::Public, ASR::presenceType::Required, false));
    scope->add_symbol(var_name, temporary_variable);

    return ASRUtils::EXPR(ASR::make_Var_t(al, temporary_variable->base.loc, temporary_variable));
}

bool set_allocation_size(Allocator& al, ASR::expr_t* value, Vec<ASR::dimension_t>& allocate_dims) {
    LCOMPILERS_ASSERT(ASRUtils::is_array(ASRUtils::expr_type(value)));
    switch( value->type ) {
        case ASR::exprType::FunctionCall: {
            ASR::FunctionCall_t* function_call = ASR::down_cast<ASR::FunctionCall_t>(value);
            ASR::ttype_t* type = function_call->m_type;
            if( ASRUtils::is_allocatable(type) ) {
                return false;
            }
            ASRUtils::ExprStmtDuplicator duplicator(al);
            ASR::dimension_t* dims = nullptr;
            size_t n_dims = ASRUtils::extract_dimensions_from_ttype(type, dims);
            allocate_dims.reserve(al, n_dims);
            for( size_t i = 0; i < n_dims; i++ ) {
                ASR::dimension_t dim = dims[i];
                ASR::dimension_t dim_copy;
                dim_copy.loc = dim.loc;
                dim_copy.m_start = !dim.m_start ? nullptr : duplicator.duplicate_expr(dim.m_start);
                dim_copy.m_length = !dim.m_length ? nullptr : duplicator.duplicate_expr(dim.m_length);
                allocate_dims.push_back(al, dim_copy);
            }
            break ;
        }
        default: {
            LCOMPILERS_ASSERT_MSG(false, "ASR::exprType::" + std::to_string(value->type)
                + " not handled yet in set_allocation_size");
        }
    }
    return true;
}

void insert_allocate_stmt(Allocator& al, ASR::expr_t* temporary_var,
    ASR::expr_t* value, Vec<ASR::stmt_t*>* current_body) {
    if( !ASRUtils::is_allocatable(temporary_var) ) {
        return ;
    }
    Vec<ASR::dimension_t> allocate_dims;
    if( !set_allocation_size(al, value, allocate_dims) ) {
        return ;
    }
    Vec<ASR::alloc_arg_t> alloc_args; alloc_args.reserve(al, 1);
    ASR::alloc_arg_t alloc_arg;
    alloc_arg.loc = value->base.loc;
    alloc_arg.m_a = temporary_var;
    alloc_arg.m_dims = allocate_dims.p;
    alloc_arg.n_dims = allocate_dims.size();
    alloc_arg.m_len_expr = nullptr;
    alloc_arg.m_type = nullptr;
    alloc_args.push_back(al, alloc_arg);

    current_body->push_back(al, ASRUtils::STMT(ASR::make_Allocate_t(al,
        temporary_var->base.loc, alloc_args.p, alloc_args.size(),
        nullptr, nullptr, nullptr)));
}

class Simplifier: public ASR::CallReplacerOnExpressionsVisitor<Simplifier>
{

    private:

    Allocator& al;
    Vec<ASR::stmt_t*>* current_body;

    public:

    Simplifier(Allocator& al_) : al(al_), current_body(nullptr) {}

    void transform_stmts(ASR::stmt_t **&m_body, size_t &n_body) {
        Vec<ASR::stmt_t*>* current_body_copy = current_body;
        Vec<ASR::stmt_t*> current_body_vec; current_body_vec.reserve(al, 1);
        current_body_vec.from_pointer_n(m_body, n_body);
        current_body = &current_body_vec;
        for (size_t i = 0; i < n_body; i++) {
            visit_stmt(*m_body[i]);
            current_body->push_back(al, m_body[i]);
        }
        m_body = current_body_vec.p; n_body = current_body_vec.size();
        current_body = current_body_copy;
    }

    void visit_Print(const ASR::Print_t& x) {
        const Location& loc = x.base.base.loc;
        Vec<ASR::expr_t*> x_m_values; x_m_values.reserve(al, x.n_values);
        /* For frontends like LC, we will need to traverse the print statement arguments
           in reverse order. */
        for( size_t i = 0; i < x.n_values; i++ ) {
            if( ASRUtils::is_array(ASRUtils::expr_type(x.m_values[i])) ) {
                ASR::expr_t* array_var_temporary = create_temporary_variable_for_array(
                    al, x.m_values[i], current_scope, "print");
                insert_allocate_stmt(al, array_var_temporary, x.m_values[i], current_body);
                current_body->push_back(al, ASRUtils::STMT(ASR::make_Assignment_t(
                    al, loc, array_var_temporary, x.m_values[i], nullptr)));
                x_m_values.push_back(al, array_var_temporary);
            } else {
                x_m_values.push_back(al, x.m_values[i]);
            }
        }

        ASR::Print_t& xx = const_cast<ASR::Print_t&>(x);
        xx.m_values = x_m_values.p;
        xx.n_values = x_m_values.size();
    }

};

void pass_simplifier(Allocator &al, ASR::TranslationUnit_t &unit,
                     const PassOptions &/*pass_options*/) {
    Simplifier v(al);
    v.visit_TranslationUnit(unit);
}


} // namespace LCompilers
