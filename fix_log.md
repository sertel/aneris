# Status quo

0. The build is still complaining about `find: 'external': No such file or directory` -> figure out where we missed to remove a reference to external 

1. The first three (code) errors all involve the set_solver
   -> it's a tactic from stdpp did it change? 
    -> judging from coq-aneris.opam aneris relied on coq 8.16
    -> judging from the external/stdpp git-submodule aneris relied on stdpp version tested with 8.17.
    which is before stdpp 1.9.
    -> latest is 1.10. and we probably need that with coq 8.19.
  
    => did set_sovler change between 24.04.2024 and now?
    => this seems to be the only change to set_solver in the relevant timeframe:
        https://gitlab-10.mpi-sws.org/iris/stdpp/-/commit/b37cd70f7bb1424ea386c1b63a578a927a1ae2e0#d8a7e069c0f6e1b05686c673c19f4d708b727030_350_350
    
    => tried with local definition of a set_solver_roleback, using it didn't remove the 
        "No matching clauses for match" problem
    => The error is understandable as there is a `match goal` in the tactic ... yet I don't know how this was supposed to work 
    with an older version of coq/stdpp as the match didn't change 
    
    => next hint ... f a k (term in the goal) is not a set but a gset 
    => stepping through the tactic steps it turns out that most of them don't do anything and the matching fails in the naive_solver step

    => let's check if there are changes in gset and set in general
    => gset comes from iris, not stdpp and in fact there are 2 commits in the last month 
       that added gset support to set_solver
       => BUT that makes me wonder how this could be problem i.e. how it worked before 
          and doesn't work any more now :-/
        https://gitlab-10.mpi-sws.org/iris/iris/-/commits/master/iris/algebra/gset.v?ref_type=heads

    => or did naive_solver change ??
       there is only one change in the naive_solver tactic that is less than a two years 
       old 
       https://gitlab-10.mpi-sws.org/iris/stdpp/-/commit/1249ca869c17f010fdc3e672d7ea4c8d6c75d7c9#d0565cab4969ed0fe16867e6b0001f04e55fe775_850_763