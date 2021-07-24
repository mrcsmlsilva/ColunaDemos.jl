function model(data::DataSmMiLs, optimizer, use_direct_model = true)
    mils = BlockModel(optimizer, direct_model = use_direct_model)

    @axis(S, 1:data.nbscenarios)

    I = 1:data.nbitems
    T = 1:data.nbperiods

    D = zeros(Int, data.nbitems, data.nbperiods, data.nbperiods, data.nbscenarios)
    for i in I
        for t in T
            for l in t:data.nbperiods
                for s in S
                    f = (l > t ? l-1 : t)
                    D[i,t,l,s] = D[i,t,f,s] + d(data, i, l, s)
                end
            end
        end
    end

    M = zeros(Int, data.nbitems)
    for i in I
        for t in T
            sum = 0
            for s in S
                sum += d(data, i, t, s)
            end
            if sum > 0
                M[i] = t
                break
            end
        end
    end

    @variable(mils, 0<= x[i in I, t in T, l in T, s in S] <= 1)
    
    @variable(mils, y[i in I, t in T], Bin)

    @constraint(mils, singlemode[t in T],
                sum(y[i, t] for i in I) <= 1
                )

    #== @constraint(mils, baseCut[i in I],
                sum(y[i, t] for  t in 1:M[i])  >= 1
                ) ==#

    @constraint(mils, setup[i in I, t in T, s in S],
                sum(x[i, t, l, s] for  l in t:data.nbperiods) -  y[i, t] <= 0
                )

    @constraint(mils, cov[i in I,   s in S], 
                sum(x[i, i, t, s] for  t in i:data.nbperiods) >= 1
                )

    last = data.nbperiods-1
    @constraint(mils, balance[i in I, t in 1:last, s in S],
                sum(x[i, t+1, τ, s] for τ in t+1:data.nbperiods) >= sum(x[i, τ, t, s] for τ in 1:t)
                )

    @constraint(mils, zero[i in I, t in 2:data.nbperiods, s in S],
                sum(x[i, t, τ, s] for τ in 1:t-1) <= 0 
                ) 

    obj = @objective(mils, Min, 
               sum(c(data, i, t) * D[i, t, l, s] * x[i, t, l, s] for i in I, t in T, l in t:data.nbperiods, s in S) +
               sum(s(data, i, t) * y[i, t] for i in I, t in T)
               )

    @benders_decomposition(mils, dec, S)    

    return mils, dec, x, y
end
