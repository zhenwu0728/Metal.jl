# indexing

using Base.Cartesian

Base.to_index(::MtlArray, I::AbstractArray{Bool}) = findall(I)
if VERSION >= v"1.11.0-DEV.1157"
    Base.to_indices(A::MtlArray, I::Tuple{AbstractArray{Bool}}) = (Base.to_index(A, I[1]),)
else
    Base.to_indices(A::MtlArray, inds,
                    I::Tuple{Union{Array{Bool,N}, BitArray{N}}}) where {N} =
        (Base.to_index(A, I[1]),)
end

function Base.findall(bools::WrappedMtlArray{Bool})
    I = keytype(bools)
    indices = cumsum(reshape(bools, prod(size(bools))))

    n = @allowscalar indices[end]
    ys = MtlArray{I}(undef, n)

    if n > 0
        function kernel(ys::MtlDeviceArray, bools, indices)
            i = (threadgroup_position_in_grid_3d().x - Int32(1)) * threads_per_threadgroup_3d().x + thread_position_in_threadgroup_3d().x

            @inbounds if i <= length(bools) && bools[i]
                i′ = CartesianIndices(bools)[i]
                b = indices[i]   # new position
                ys[b] = i′
            end

            return
        end

        kernel = @metal name="findall" launch=false kernel(ys, bools, indices)
        threads = Int(kernel.pipeline.maxTotalThreadsPerThreadgroup)
        kernel(ys, bools, indices; threads)
    end

    unsafe_free!(indices)

    return ys
end

function Base.findall(f::Function, A::WrappedMtlArray)
    bools = map(f, A)
    ys = findall(bools)
    unsafe_free!(bools)
    return ys
end