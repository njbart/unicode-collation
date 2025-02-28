{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module UnicodeCollation.Collator
  ( collator
  , collationOptions
  , collatorFor
  , mkCollator
  , withTailoring
  )
where

import UnicodeCollation.Types
import UnicodeCollation.Lang
import UnicodeCollation.Tailorings
import UnicodeCollation.Collation (getCollationElements)
import Data.Word (Word16)
import qualified Data.Text.Normalize as N
import qualified Data.Text as T
import Data.Text (Text)
import Data.Ord (comparing)
import Data.Char (ord)
import Language.Haskell.TH.Quote (QuasiQuoter(..))
#if MIN_VERSION_base(4,11,0)
#else
import Data.Semigroup (Semigroup(..))
#endif

-- | Create a collator at compile time based on a BCP47 language
-- tag: e.g., @[collator|es-u-co-trad]@.  Requires the @QuasiQuotes@ extension.
collator :: QuasiQuoter
collator = QuasiQuoter
  { quoteExp = \langtag -> do
      case parseLang (T.pack langtag) of
        Left e -> do
          fail $ "Could not parse BCP47 tag " <> langtag <> e
        Right lang ->
          case lookupLang lang tailorings of
            Nothing    ->
              fail $ "No match (even inexact) found for " <> langtag
            Just (_, _) ->
              [| collatorFor lang |]
  , quotePat = undefined
  , quoteType = undefined
  , quoteDec = undefined
  }


-- | Default 'CollationOptions'.
collationOptions :: CollationOptions
collationOptions =
  CollationOptions
  { optVariableWeighting = NonIgnorable
  , optFrenchAccents     = False
  , optNormalize         = True
  , optCollation         = rootCollation
  }



-- | Returns a collator based on a BCP 47 language tag.
-- If no exact match is found, we try to find the best match
-- (falling back to the root collation if nothing else succeeds).
-- If something other than the default collation for a language
-- is desired, the @co@ keyword of the unicode extensions can be
-- used (e.g. @es-u-co-trad@ for traditional Spanish).
-- The language tag affects not just the collation but the collator
-- options.  The 'optFrenchAccents' option will be set if the
-- unicode extensions (after @-u-@) include the @kb@ keyword
-- (e.g. @fr-FR-u-kb-true@).
-- The 'optVariableWeight' option will be set if the
-- unicode extensions include the @ka@ keyword (e.g. @fr-FR-u-kb-ka-shifted@
-- or @en-u-ka-noignore@).
-- The 'optNormalize' option will be set if the unicode extensions
-- include the @kk@ keyword (e.g. @fr-u-kk-false@).
collatorFor :: Lang -> Collator
collatorFor lang = mkCollator opts
  where
    opts = collationOptions{
             optFrenchAccents =
               case lookup "u" exts >>= lookup "kb" of
                 Just ""       -> True
                                       -- true is default attribute value
                 Just "true"   -> True
                 _             -> False,
             optVariableWeighting =
               case lookup "u" exts >>= lookup "ka" of
                 Just ""         -> NonIgnorable
                 Just "noignore" -> NonIgnorable
                 Just "shifted"  -> Shifted
                 _               -> NonIgnorable,
             optNormalize =
               case lookup "u" exts >>= lookup "kk" of
                 Just ""         -> True
                 Just "true"     -> True
                 Just "false"    -> False
                 _               -> True,
             optCollation = rootCollation `tailorCollation` tailoring }
    tailoring = maybe mempty snd $ lookupLang lang tailorings
    exts = langExtensions lang

-- | Apply a 'Tailoring' to a 'Collator.
withTailoring :: Collator -> Tailoring -> Collator
withTailoring coll tailoring =
  let oldCollation = optCollation (collatorOptions coll)
   in mkCollator (collatorOptions coll){
                   optCollation = tailorCollation oldCollation tailoring }

-- | Returns a collator constructed using the collation and
-- variable weighting specified in the options.
mkCollator :: CollationOptions -> Collator
mkCollator opts =
  Collator { collate = comparing sortKey'
           , sortKey = sortKey'
           , collatorOptions = opts
           }
 where
  sortKey' = toSortKey opts

toSortKey :: CollationOptions -> Text -> SortKey
toSortKey opts =
    mkSortKey opts
  . handleVariable (optVariableWeighting opts)
  . getCollationElements (optCollation opts)
  . T.foldr ((:) . ord) []
  . if optNormalize opts
       then N.normalize N.NFD
       else id

handleVariable :: VariableWeighting -> [CollationElement] -> [CollationElement]
handleVariable NonIgnorable = id
handleVariable Blanked = doVariable False False
handleVariable Shifted = doVariable True False
handleVariable ShiftTrimmed = handleVariable Shifted

doVariable :: Bool -> Bool -> [CollationElement] -> [CollationElement]
doVariable _useL4 _afterVariable [] = []
doVariable useL4 afterVariable (e:es)
  | collationVariable e
    =   e{ collationL1 = 0, collationL2 = 0, collationL3 = 0,
           collationL4 = -- Table 11
             case useL4 of
               True
                 | collationL1 e == 0
                 , collationL2 e == 0
                 , collationL3 e == 0   -> 0
                 | collationL1 e == 0
                 , collationL3 e /= 0
                 , afterVariable        -> 0
                 | collationL1 e /= 0   -> collationL1 e
                 | collationL1 e == 0
                 , collationL3 e /= 0
                 , not afterVariable    -> 0xFFFF
               _                        -> 0
         } : doVariable useL4 True es
  | collationL1 e == 0 -- "ignorable"
  , afterVariable
    = e{ collationL1 = 0, collationL2 = 0, collationL3 = 0, collationL4 = 0 }
       : doVariable useL4 afterVariable es
  | collationL1 e /= 0
  , not (collationVariable e)
  , useL4
  = e{ collationL4 = 0xFFFF } : doVariable useL4 False es
  | otherwise
    = e : doVariable useL4 False es

mkSortKey :: CollationOptions -> [CollationElement] -> SortKey
mkSortKey opts elts = SortKey $
    l1s ++ (0:l2s) ++ (0:l3s) ++ if null l4s then [] else (0:l4s)
  where
    l1s = filter (/=0) $ map collationL1 elts
    l2s = (if optFrenchAccents opts
              then reverse
              else id) $ filter (/=0) $ map collationL2 elts
    l3s = filter (/=0) $ map collationL3 elts
    l4s = (case optVariableWeighting opts of
             ShiftTrimmed -> trimTrailingFFFFs
             _             -> id) $ filter (/=0) $ map collationL4 elts

trimTrailingFFFFs :: [Word16] -> [Word16]
trimTrailingFFFFs = reverse . dropWhile (== 0xFFFF) . reverse

