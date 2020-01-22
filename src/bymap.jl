import Base.Cartesian.@ntuple

const ParticleArray = AbstractArray{<:AbstractParticles}
const SomeKindOfParticles = Union{<:MonteCarloMeasurements.AbstractParticles, ParticleArray}


nparticles(p) = length(p)
nparticles(p::ParticleArray) = length(eltype(p))
nparticles(p::AbstractParticles{T,N}) where {T,N} = N
nparticles(p::Type{<:ParticleArray}) = length(eltype(p))

particletype(p::AbstractParticles) = typeof(p)
particletype(::Type{P}) where P <: AbstractParticles = P
particletype(p::AbstractArray{<:AbstractParticles}) = eltype(p)

vecindex(p,i) = getindex(p,i)
vecindex(p::ParticleArray,i) = getindex.(p,i)
vecindex(p::NamedTuple,i) = (; Pair.(keys(p), ntuple(j->arggetter(i,p[j]), fieldcount(typeof(p))))...)

function indexof_particles(args)
    inds = findall(a-> a <: SomeKindOfParticles, args)
    inds === nothing && throw(ArgumentError("At least one argument should be <: AbstractParticles. If particles appear nested as fields inside an argument, see `with_workspace` and `Workspace`"))
    all(nparticles(a) == nparticles(args[inds[1]]) for a in args[inds]) || throw(ArgumentError("All p::Particles must have the same number of particles."))
    (inds...,)
    # TODO: test all same number of particles
end


function arggetter(i,a::Union{SomeKindOfParticles, NamedTuple})
    vecindex(a,i)
end

function arggetter(i,a)
    a
end

"""
    @bymap f(p, args...)

Call `f` with particles or vectors of particles by using `map`. This can be utilized if registering `f` using [`register_primitive`](@ref) fails. See also [`Workspace`](@ref) if `bymap` fails.
"""
macro bymap(ex)
    @capture(ex, f_(args__)) || error("expected a function call")
    quote
        bymap($(esc(f)),$(esc.(args)...))
    end
end

"""
    bymap(f, args...)

Call `f` with particles or vectors of particles by using `map`. This can be utilized if registering `f` using [`register_primitive`](@ref) fails. See also [`Workspace`](@ref) if `bymap` fails.
"""
function bymap(f::F, args...) where F
    inds = indexof_particles(typeof.(args))
    T,N,PT = particletypetuple(args[first(inds)])
    individuals = map(1:N) do i
        argsi = ntuple(j->arggetter(i,args[j]), length(args))
        f(argsi...)
    end
    PTNT = PT{eltype(eltype(individuals)),N}
    if (eltype(individuals) <: AbstractArray{TT,0} where TT) || eltype(individuals) <: Number
        PTNT(individuals)
    elseif eltype(individuals) <: AbstractArray{TT,1} where TT
        PTNT(copy(reduce(hcat,individuals)'))
    elseif eltype(individuals) <: AbstractArray{TT,2} where TT
        # @show PT{eltype(individuals),N}
        reshape(PTNT(copy(reduce(hcat,vec.(individuals))')), size(individuals[1],1),size(individuals[1],2))::Matrix{PTNT}
    else
        error("Output with dimension >2 is currently not supported by `bymap`. Consider if `ℝⁿ2ℝⁿ_function($(f), $(args...))` works for your use case.")
    end
end

# p = 1 ± 1
# bymap(sin, p) == sin(p)


function bypmap(f::F, args...) where F
    inds = indexof_particles(typeof.(args))
    T,N,PT = particletypetuple(args[first(inds)])
    individuals = map(1:N) do i
        argsi = ntuple(j->arggetter(i,args[j]), length(args))
        f(argsi...)
    end
    PTNT = PT{eltype(eltype(individuals)),N}
    if (eltype(individuals) <: AbstractArray{TT,0} where TT) || eltype(individuals) <: Number
        PTNT(individuals)
    elseif eltype(individuals) <: AbstractArray{TT,1} where TT
        PTNT(copy(reduce(hcat,individuals)'))
    elseif eltype(individuals) <: AbstractArray{TT,2} where TT
        # @show PT{eltype(individuals),N}
        reshape(PTNT(copy(reduce(hcat,vec.(individuals))')), size(individuals[1],1),size(individuals[1],2))::Matrix{PTNT}
    else
        error("Output with dimension >2 is currently not supported by `bymap`. Consider if `ℝⁿ2ℝⁿ_function($(f), $(args...))` works for your use case.")
    end
end

"""
    @bypmap f(p, args...)

Call `f` with particles or vectors of particles by using parallel `pmap`. This can be utilized if registering `f` using [`register_primitive`](@ref) fails. See also [`Workspace`](@ref) if `bymap` fails.
"""
macro bypmap(ex)
    @capture(ex, f_(args__)) || error("expected a function call")
    quote
        bypmap($(esc(f)),$(esc.(args)...))
    end
end
