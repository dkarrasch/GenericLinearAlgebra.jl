using Test, GenericLinearAlgebra, LinearAlgebra, Quaternions, DoubleFloats

@testset "Singular value decomposition" begin
    @testset "Problem dimension ($m,$n)" for
        (m,n) in ((6,5)     , (6,6)     , (5,6),
                  (60, 50)  , (60, 60)  , (50, 60),
                  (200, 150), (200, 200), (150, 200))

        vals = reverse(collect(1:min(m,n)))
        U = qr(Quaternion{Float64}[Quaternion(randn(4)...) for i = 1:m, j = 1:min(m,n)]).Q
        V = qr(Quaternion{Float64}[Quaternion(randn(4)...) for i = 1:n, j = 1:min(m,n)]).Q

        # FixMe! Using Array here shouldn't be necessary. Can be removed once
        # the bug in LinearAlgebra is fixed
        A = U*Array(Diagonal(vals))*V'

        @test size(A) == (m, n)
        @test vals ≈ svdvals(A)

        F = svd(A)
        @test vals ≈ F.S
        @show norm(F.U'*A*F.V - Diagonal(F.S), Inf)
        @test F.U'*A*F.V ≈ Diagonal(F.S)
    end

    @testset "The Ivan Slapničar Challenge" begin
        # This matrix used to hang (for n = 70). Thanks to Ivan Slapničar for reporting.
        n = 70
        J = Bidiagonal(0.5 * ones(n), ones(n-1), :U)
        @test GenericLinearAlgebra._svdvals!(copy(J)) ≈ svdvals(J)
        @test GenericLinearAlgebra._svdvals!(copy(J))[end] / svdvals(J)[end] - 1 < n*eps()
    end

    @testset "Compare to Base methods. Problem dimension ($m,$n)" for
        (m, n) in ((10,  9), # tall
                   (10, 10), # square
                   (9 , 10)) # wide

        A    = randn(m,n)
        Abig = big.(A)
        @test svdvals(A) ≈ Vector{Float64}(svdvals(Abig))
        @test cond(A)    ≈ Float64(cond(Abig))

        F    = svd(A)
        Fbig = svd(Abig)
        @test abs.(F.U'Float64.(Fbig.U)) ≈ I
        @test abs.(F.V'Float64.(Fbig.V)) ≈ I

        F    = svd(A, full=true)
        Fbig = svd(Abig, full=true)
        @test abs.(F.U'Float64.(Fbig.U)) ≈ I
        @test abs.(F.V'Float64.(Fbig.V)) ≈ I
    end

    @testset "Issue 54" begin
        U0, _, V0 = svd(big.(reshape(0:15, 4, 4)))
        A = U0[:, 1:3] * V0[:, 1:3]'

        U, S, V = svd(A)
        @test A ≈ U*Diagonal(S)*V'
    end

    @testset "Very small matrices. Issue 79" begin
        A = randn(1, 2)
        FA = svd(A)
        FAb = svd(big.(A))
        FAtb = svd(big.(A'))
        @test FA.S ≈ Float64.(FAb.S) ≈ Float64.(FAtb.S)
        @test abs.(FA.U'*Float64.(FAb.U))  ≈ I
        @test abs.(FA.U'*Float64.(FAtb.V)) ≈ I
        @test abs.(FA.V'*Float64.(FAb.V))  ≈ I
        @test abs.(FA.V'*Float64.(FAtb.U)) ≈ I
    end

    @testset "Issue 81" begin
        A = [1 0 0 0; 0 2 1 0; 0 1 2 0; 0 0 0 -1]
        @test Float64.(svdvals(big.(A))) ≈ svdvals(A)

        A = [
            0.3   0.0   0.0  0.0  0.0  0.2  0.3   0.0;
            0.0   0.0   0.0  0.0  0.1  0.0  0.0   0.0;
            0.0  -0.2   0.0  0.0  0.0  0.0  0.0  -0.2;
            0.3   0.0   0.0  0.0  0.0  0.2  0.4   0.0;
            0.0   0.4  -0.2  0.0  0.0  0.0  0.0   0.3;
            0.2   0.0   0.0  0.0  0.0  0.0  0.2   0.0;
            0.0   0.0   0.0  0.1  0.0  0.0  0.0   0.0;
            0.0   0.3  -0.2  0.0  0.0  0.0  0.0   0.3
        ]
        @test GenericLinearAlgebra._svdvals!(
            GenericLinearAlgebra.bidiagonalize!(copy(A)).bidiagonal
        ) ≈ svdvals(A)

        n = 17
        A = zeros(Double64, n, n)
        for j in 1:n, i in 1:n
            A[i, j] = 1 / Double64(i + j - 1)
        end
        @test svdvals(A) ≈ svdvals(Float64.(A))

        # From https://github.com/JuliaMath/DoubleFloats.jl/issues/149
        n = 64
        c = Complex{BigFloat}(3//1 + 1im//1)
        A = diagm(
            1 => c*ones(BigFloat, n - 1),
            -1 => c*ones(BigFloat,n - 1),
            -2 => ones(BigFloat, n - 2)
        )
        @test svdvals(A) ≈ svdvals(Complex{Double64}.(A))
    end
end
