-- | Command-line argument handling.
module Args where

import Data.Char (toLower)
import Options.Applicative
import Distribution.PackageDescription (FlagAssignment, FlagName(..))
import System.FilePath (FilePath)

import Fields

data Args = Args
  { cabalFile :: Maybe FilePath
  , flags     :: FlagAssignment
  , field     :: Maybe FieldName
  }
  deriving Show

-- | Parse the command-line arguments.
getArgs :: IO Args
getArgs = execParser opts where
  opts = info (helper <*> argsParser)
    (fullDesc <> progDesc "Print fields from a cabal file.")

-------------------------------------------------------------------------------
-- Parsers

argsParser :: Parser Args
argsParser = Args
  <$> optional (strOption
      $  long "cabal-file"
      <> metavar "FILE"
      <> help "The cabal file to use. If unspecified, the first one found in this directory is used instead.")

  <*> flagAssignmentParser

  <*> optional fieldNameParser

flagAssignmentParser :: Parser FlagAssignment
flagAssignmentParser = map go . words <$> strOption (long "flags" <> short 'f' <> metavar "FLAGS" <> help "Force values for the given flags in Cabal conditionals in the .cabal file. E.g. --flags=\"debug -usebytestrings\" forces the flag \"debug\" to true and the flag \"usebytestrings\" to false." <> value "") where

  go ('-':flag) = (FlagName flag, False)
  go flag = (FlagName flag, True)

fieldNameParser :: Parser FieldName
fieldNameParser = go <$> argument str (metavar "FIELD" <> help "This is in the format [section:]field, where the section can be the name of a source repository, executable, test suite, or benchmark. If no field is given, then the file is pretty-printed, with any flags applied.") where
  go fname = case break (==':') fname of
    (name, ':':field) -> FieldName (Just $ map toLower name) (map toLower field)
    (field, []) -> FieldName Nothing (map toLower field)