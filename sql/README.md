# Using traces to compute ngrams

## Assumption

- local view on functions context
- comparing traces from production and test
- scale to several traces of at least 1M calls
- also work on small config
- incremental results

## Idea

Local view and scaling lead to incremental and distributed computation.
One easy way of inplementing an algorithm that scale is using sql models.
For the implementation we will use postgres as it is made for rapid prototyping of sql algorithm,
but we can think of other systems like GPGPU or Grid computation with MPI,
the key point of postgres here is that it offload a big part of the optimisation
from the developper and is tightly due to sql model

## Algorithm

Given a line/symbol/fontcion name and traces we explore incrementally before and after
the initial symbol, so the moves in the traces look like a binary tree,
left branches mean look at the previous symbol and next at the next symbol.
The aim is to produce ngrams containing the initial symbol,
so each ngram will be represented as its starting position in the trace and its size.
We will keep an intermediary data structures,
it represent a direct mapping between traces and ngrams,
results of the computations are stored for later use
it contain all the information relative to each ngram,
like the number of occurencies in production and in tests
but also the position and name of the initial symbol.
The main trick is to avoid repretenting the same ngram multiple times.

## Implementation

### Tables

Calls: _traceId line_ **symbol** parameters
AccTable: _**n** traceId left_ **hash** shift isLeft isRight
GroupTable: **symbol** _n hash shift_ pocc tocc

### Fonctions

initExploration(symbol)
continueExploration(symbol)
getNgrams(symbol)
getNgrams(symbol, n_max)