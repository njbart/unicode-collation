{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE OverloadedStrings #-}
module UnicodeCollation.CombiningClass
  ( genCombiningClassMap
  )
where
import Data.Maybe
import Data.Text (Text)
import qualified Data.Binary as Binary
import qualified Data.Text as T
import qualified Data.Text.IO as T
import qualified Data.Text.Read as TR
import qualified Data.IntMap as M
import Language.Haskell.TH
import Language.Haskell.TH.Syntax (qAddDependentFile)
import qualified Data.ByteString.Lazy.Char8 as BL

genCombiningClassMap :: FilePath -> Q Exp
genCombiningClassMap fp  = do
  qAddDependentFile fp
  binaryRep <- Binary.encode . parseDerivedCombiningClass <$>
                  runIO (T.readFile fp)
  return $ LitE $ StringL $ BL.unpack binaryRep


parseDerivedCombiningClass :: Text -> M.IntMap Int
parseDerivedCombiningClass =
  M.fromList . concat . mapMaybe parseLine . T.lines

parseLine :: Text -> Maybe [(Int, Int)]
parseLine t =
  case TR.hexadecimal t of
    Left _ -> Nothing
    Right (lower, rest) ->
      let (upper, rest') =
            if ".." `T.isPrefixOf` rest
               then case TR.hexadecimal (T.drop 2 rest) of
                      Left                 _ -> (lower, rest)
                      Right (upper', rest'') -> (upper', rest'')
               else (lower, rest)
       in case TR.decimal $ T.drop 2 $ T.dropWhile (/=';') rest' of
            Left _ -> Nothing
            Right (0, _) -> Nothing -- don't include 0 values
            Right (category :: Int, _)
                   -> Just $ map (,category) (enumFromTo lower upper)

