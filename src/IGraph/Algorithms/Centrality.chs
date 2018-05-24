{-# LANGUAGE ForeignFunctionInterface #-}
module IGraph.Algorithms.Centrality
    ( closeness
    , betweenness
    , eigenvectorCentrality
    , pagerank
    ) where

import           Control.Monad
import           Data.Serialize            (Serialize)
import Data.List (foldl')
import           System.IO.Unsafe          (unsafePerformIO)
import Data.Maybe
import Data.Singletons (SingI)

import Foreign
import Foreign.C.Types

import           IGraph
{#import IGraph.Internal #}
{#import IGraph.Internal.Constants #}

#include "haskell_igraph.h"

-- | The normalized closeness centrality of a node is the average length of the
-- shortest path between the node and all other nodes in the graph.
closeness :: [Int]  -- ^ vertices
          -> Graph d v e
          -> Maybe [Double]  -- ^ optional edge weights
          -> Bool   -- ^ whether to normalize the results
          -> [Double]
closeness nds gr ws normal = unsafePerformIO $ allocaVector $ \result ->
    withVerticesList nds $ \vs -> withListMaybe ws $ \ws' -> do
        igraphCloseness (_graph gr) result vs IgraphOut ws' normal
        toList result
{#fun igraph_closeness as ^
    { `IGraph'
    , castPtr `Ptr Vector'
    , castPtr %`Ptr VertexSelector'
    , `Neimode'
    , castPtr `Ptr Vector'
    , `Bool' } -> `CInt' void- #}


-- | Betweenness centrality
betweenness :: [Int]
            -> Graph d v e
            -> Maybe [Double]
            -> [Double]
betweenness nds gr ws = unsafePerformIO $ allocaVector $ \result ->
    withVerticesList nds $ \vs -> withListMaybe ws $ \ws' -> do
        igraphBetweenness (_graph gr) result vs True ws' False
        toList result
{#fun igraph_betweenness as ^
    { `IGraph'
    , castPtr `Ptr Vector'
    , castPtr %`Ptr VertexSelector'
    , `Bool'
    , castPtr `Ptr Vector'
    , `Bool' } -> `CInt' void- #}

-- | Eigenvector centrality
eigenvectorCentrality :: Graph d v e
                      -> Maybe [Double]
                      -> [Double]
eigenvectorCentrality gr ws = unsafePerformIO $ allocaArpackOpt $ \arparck ->
    allocaVector $ \result -> withListMaybe ws $ \ws' -> do
        igraphEigenvectorCentrality (_graph gr) result nullPtr True True ws' arparck
        toList result
{#fun igraph_eigenvector_centrality as ^
    { `IGraph'
    , castPtr `Ptr Vector'
    , id `Ptr CDouble'
    , `Bool'
    , `Bool'
    , castPtr `Ptr Vector'
    , castPtr `Ptr ArpackOpt' } -> `CInt' void- #}

-- | Google's PageRank algorithm, with option to
pagerank :: SingI d
         => Graph d v e
         -> Maybe [Double]  -- ^ Node weights or reset probability. If provided,
                            -- the personalized PageRank will be used
         -> Maybe [Double]  -- ^ Edge weights
         -> Double  -- ^ damping factor, usually around 0.85
         -> [Double]
pagerank gr reset ws d
    | n == 0 = []
    | isJust ws && length (fromJust ws) /= m = error "incorrect length of edge weight vector"
    | isJust reset && length (fromJust reset) /= n = error
        "incorrect length of node weight vector"
    | fmap (foldl' (+) 0) reset == Just 0 = error "sum of node weight vector must be non-zero"
    | otherwise = unsafePerformIO $ alloca $ \p -> allocaVector $ \result ->
        withVerticesAll $ \vs -> withListMaybe ws $ \ws' -> do
            case reset of
                Nothing -> igraphPagerank (_graph gr) IgraphPagerankAlgoPrpack
                    result p vs (isDirected gr) d ws' nullPtr
                Just reset' -> withList reset' $ \reset'' -> igraphPersonalizedPagerank
                    (_graph gr) IgraphPagerankAlgoPrpack result p vs
                    (isDirected gr) d reset'' ws' nullPtr
            toList result
  where
    n = nNodes gr
    m = nEdges gr

{#fun igraph_pagerank as ^
    { `IGraph'
    , `PagerankAlgo'
    , castPtr `Ptr Vector'
    , id `Ptr CDouble'
    , castPtr %`Ptr VertexSelector'
    , `Bool'
    , `Double'
    , castPtr `Ptr Vector'
    , id `Ptr ()'
    } -> `CInt' void- #}

{#fun igraph_personalized_pagerank as ^
    { `IGraph'
    , `PagerankAlgo'
    , castPtr `Ptr Vector'
    , id `Ptr CDouble'
    , castPtr %`Ptr VertexSelector'
    , `Bool'
    , `Double'
    , castPtr `Ptr Vector'
    , castPtr `Ptr Vector'
    , id `Ptr ()'
    } -> `CInt' void- #}