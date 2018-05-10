{-# LANGUAGE ForeignFunctionInterface #-}
module IGraph.Structure
    ( inducedSubgraph
    , closeness
    , betweenness
    , eigenvectorCentrality
    , pagerank
    ) where

import           Control.Monad
import           Data.Either               (fromRight)
import           Data.Hashable             (Hashable)
import qualified Data.HashMap.Strict       as M
import           Data.Serialize            (Serialize, decode)
import           System.IO.Unsafe          (unsafePerformIO)
import Data.Maybe
import Data.Singletons (SingI)

import Foreign
import Foreign.C.Types

import           IGraph
import           IGraph.Mutable (MGraph(..))
{#import IGraph.Internal #}
{#import IGraph.Internal.Constants #}

#include "igraph/igraph.h"

inducedSubgraph :: (Hashable v, Eq v, Serialize v)
                => Graph d v e
                -> [Int]
                -> Graph d v e
inducedSubgraph gr nds = unsafePerformIO $ withVerticesList nds $ \vs ->
    igraphInducedSubgraph (_graph gr) vs IgraphSubgraphCreateFromScratch >>=
        unsafeFreeze . MGraph
{#fun igraph_induced_subgraph as ^
    { `IGraph'
    , allocaIGraph- `IGraph' addIGraphFinalizer*
    , castPtr %`Ptr VertexSelector'
    , `SubgraphImplementation'
    } -> `CInt' void- #}

-- | Closeness centrality
closeness :: [Int]  -- ^ vertices
          -> Graph d v e
          -> Maybe [Double]  -- ^ optional edge weights
          -> Neimode
          -> Bool   -- ^ whether to normalize
          -> [Double]
closeness nds gr ws mode normal = unsafePerformIO $ allocaVector $ \result ->
    withVerticesList nds $ \vs -> withListMaybe ws $ \ws' -> do
        igraphCloseness (_graph gr) result vs mode ws' normal
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
