const QuasiArrayMulArray{p, q, T, V} = Mul{<:Any, <:Any, <:AbstractQuasiArray{T,p}, <:AbstractArray{V,q}}
const ArrayMulQuasiArray{p, q, T, V} = Mul{<:Any, <:Any, <:AbstractArray{T,p}, <:AbstractQuasiArray{V,q}}
const QuasiArrayMulQuasiArray{p, q, T, V} = Mul{<:Any, <:Any, <:AbstractQuasiArray{T,p}, <:AbstractQuasiArray{V,q}}
####
# Matrix * Vector
####
const QuasiMatMulVec{T, V} = QuasiArrayMulArray{2, 1, T, V}
const QuasiMatMulMat{T, V} = QuasiArrayMulArray{2, 2, T, V}
const QuasiMatMulQuasiMat{T, V} = QuasiArrayMulQuasiArray{2, 2, T, V}

combine_mul_styles(::MulStyle, ::QuasiArrayApplyStyle) = QuasiArrayApplyStyle()
combine_mul_styles(::QuasiArrayApplyStyle, ::MulStyle) = QuasiArrayApplyStyle()
combine_mul_styles(::DefaultArrayApplyStyle, ::QuasiArrayApplyStyle) = QuasiArrayApplyStyle()
combine_mul_styles(::QuasiArrayApplyStyle, ::DefaultArrayApplyStyle) = QuasiArrayApplyStyle()

ApplyStyle(::typeof(*), ::Type{<:AbstractQuasiArray}) = QuasiArrayApplyStyle()
ApplyStyle(::typeof(*), ::Type{<:AbstractArray}, ::Type{<:AbstractQuasiArray}) = MulStyle()
ApplyStyle(::typeof(*), ::Type{<:AbstractQuasiArray}, ::Type{<:AbstractArray}) = MulStyle()
ApplyStyle(::typeof(*), ::Type{<:AbstractQuasiArray}, ::Type{<:AbstractQuasiArray}) = MulStyle()


*(A::AbstractQuasiMatrix) = copy(A)
*(A::AbstractQuasiArray, B::AbstractQuasiArray) = mul(A, B)
*(A::AbstractArray, B::AbstractQuasiArray) = mul(A, B)
*(A::AbstractQuasiArray, B::AbstractArray) = mul(A, B)

for op in (:pinv, :inv)
    @eval $op(A::AbstractQuasiArray) = apply($op,A)
end

@inline axes(L::Ldiv{<:Any,<:Any,<:Any,<:AbstractQuasiMatrix}) = (axes(L.A, 2),axes(L.B,2))
@inline axes(L::Ldiv{<:Any,<:Any,<:Any,<:AbstractQuasiVector}) = (axes(L.A, 2),)

@inline \(A::AbstractQuasiArray, B::AbstractQuasiArray) = ldiv(A,B)
@inline \(A::AbstractQuasiArray, B::AbstractArray) = ldiv(A,B)
@inline \(A::AbstractArray, B::AbstractQuasiArray) = ldiv(A,B)

@inline /(A::AbstractQuasiArray, B::AbstractQuasiArray) = rdiv(A,B)
@inline /(A::AbstractQuasiArray, B::AbstractArray) = rdiv(A,B)
@inline /(A::AbstractArray, B::AbstractQuasiArray) = rdiv(A,B)


####
# MulQuasiArray
#####

const MulQuasiArray{T, N, Args<:Tuple} = ApplyQuasiArray{T, N, typeof(*), Args}

const MulQuasiVector{T, Args<:Tuple} = MulQuasiArray{T, 1, Args}
const MulQuasiMatrix{T, Args<:Tuple} = MulQuasiArray{T, 2, Args}

const Vec = MulQuasiVector


_ApplyArray(F, factors...) = ApplyQuasiArray(F, factors...)
_ApplyArray(F, factors::AbstractArray...) = ApplyArray(F, factors...)

MulQuasiOrArray = Union{MulArray,MulQuasiArray}

_factors(M::MulQuasiOrArray) = M.args
_factors(M) = (M,)

@inline _flatten(A::MulQuasiArray, B...) = _flatten(Applied(A), B...)
@inline flatten(A::MulQuasiArray) = ApplyQuasiArray(flatten(Applied(A)))
@inline flatten(A::SubQuasiArray{<:Any,2,<:MulQuasiArray}) = materialize(flatten(Applied(A)))



adjoint(A::MulQuasiArray) = ApplyQuasiArray(*, reverse(adjoint.(A.args))...)
transpose(A::MulQuasiArray) = ApplyQuasiArray(*, reverse(transpose.(A.args))...)

function similar(A::MulQuasiArray)
    B,a = A.args
    B*similar(a)
end

function similar(A::QuasiArrayMulArray)
    B,a = A.args
    applied(*, B, similar(a))
end

function copyto!(dest::MulQuasiArray, src::MulQuasiArray)
    d = last(dest.args)
    s = last(src.args)
    copyto!(IndexStyle(d), d, IndexStyle(s), s)
    dest
end


struct QuasiArrayLayout <: MemoryLayout end
MemoryLayout(::Type{<:AbstractQuasiArray}) = QuasiArrayLayout()
Array(M::Mul{<:Any,<:Any,<:Any,<:AbstractQuasiMatrix}) = eltype(M)[M[k,j] for k in axes(M)[1], j in axes(M)[2]]
Array(M::Mul{<:Any,<:Any,<:Any,<:AbstractQuasiVector}) = eltype(M)[M[k] for k in axes(M)[1]]
_quasi_mul(M, _) = QuasiArray(M)
_quasi_mul(M, ::NTuple{N,OneTo{Int}}) where N = Array(M)
copy(M::Mul{QuasiArrayLayout,QuasiArrayLayout}) = _quasi_mul(M, axes(M))
copy(M::Mul{QuasiArrayLayout}) = _quasi_mul(M, axes(M))
copy(M::Mul{<:Any,QuasiArrayLayout}) = _quasi_mul(M, axes(M))
copy(M::Mul{<:AbstractLazyLayout,QuasiArrayLayout}) = ApplyQuasiArray(M)
copy(M::Mul{ApplyLayout{typeof(\)},QuasiArrayLayout}) = ApplyQuasiArray(M)
copy(M::Mul{QuasiArrayLayout,<:AbstractLazyLayout}) = ApplyQuasiArray(M)


LazyArrays._vec_mul_view(a::AbstractQuasiVector, kr, ::Colon) = view(a, kr)


###
# Scalar special case, simplifies x * A and A * x
# Find an AbstractArray to latch on to by commuting
###

_lmul_scal_reduce(x::Number, A) = (x * A,)
_lmul_scal_reduce(x::Number, A::AbstractArray, B...) = (x * A, B...)
_lmul_scal_reduce(x::Number, A, B...) = (A, _lmul_scal_reduce(x, B...)...)

_rmul_scal_reduce(x::Number, Z) = (Z * x,)
_rmul_scal_reduce(x::Number, Z::AbstractArray, Y...) = (Y..., Z*x)
_rmul_scal_reduce(x::Number, Z, Y...) = (_rmul_scal_reduce(x, Y...)..., Z)

_ldiv_scal_reduce(x::Number, A) = (x \ A,)
_ldiv_scal_reduce(x::Number, A::AbstractArray, B...) = (x \ A, B...)
_ldiv_scal_reduce(x::Number, A, B...) = (A, _ldiv_scal_reduce(x, B...)...)

_rdiv_scal_reduce(x::Number, Z) = (Z / x,)
_rdiv_scal_reduce(x::Number, Z::AbstractArray, Y...) = (Y..., Z/x)
_rdiv_scal_reduce(x::Number, Z, Y...) = (_rdiv_scal_reduce(x, Y...)..., Z)

*(x::Number, A::MulQuasiArray) = ApplyQuasiArray(*, _lmul_scal_reduce(x, arguments(A)...)...)
*(A::MulQuasiArray, x::Number) = ApplyQuasiArray(*, _rmul_scal_reduce(x, reverse(arguments(A))...)...)

\(x::Number, A::MulQuasiArray) = ApplyQuasiArray(*, _ldiv_scal_reduce(x, arguments(A)...)...)
/(A::MulQuasiArray, x::Number) = ApplyQuasiArray(*, _rdiv_scal_reduce(x, reverse(arguments(A))...)...)