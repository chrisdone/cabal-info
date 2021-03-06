-- | Accessing fields from packages.
module Fields where

import Control.Applicative ((<|>))
import Data.Char (toLower)
import           Data.Maybe                             (fromMaybe, listToMaybe,
                                                         maybeToList)
import Distribution.Utils.ShortText

import Distribution.Compiler (perCompilerFlavorToList, CompilerFlavor (GHC))
import Distribution.Package
import Distribution.PackageDescription
import Distribution.Text (display)
import Distribution.Types.UnqualComponentName
import Distribution.Version

-- | A field name is a string, optionally qualified with a specific
-- executable/test-suite/benchmark.
data FieldName = FieldName (Maybe String) String
  deriving Show

-- | Get a field from a package description, returning a list of
-- values. The empty list indicates that either the field was present,
-- but contained nothing, or the field was not present.
--
-- There are a number of parts of the package description not yet
-- exposed. Doing this nicely may require more than a single-word
-- field name eg, to specify which executable or test suite is being
-- referred to.
--
-- The following don't show up in the Cabal User Guide as of
-- 2016-02-01, and so are intentionally omitted for now:
--
-- - library requiredSignatures
-- - library exposedSignatures
getField :: FieldName -> (GenericPackageDescription, PackageDescription) -> String
-- Special case pseudo-fields
---- First:
getField (FieldName Nothing "flag")       = maybe "" (getFlagField "name") . listToMaybe . genPackageFlags . fst
getField (FieldName Nothing "executable") = maybe "" (getExecutableField "name") . listToMaybe . executables . snd
getField (FieldName Nothing "testsuite")  = maybe "" (getTestSuiteField "name") . listToMaybe . testSuites . snd
getField (FieldName Nothing "benchmark")  = maybe "" (getBenchmarkField "name") . listToMaybe . benchmarks . snd
getField (FieldName Nothing "repository") = maybe "" (getSourceRepoField "name") . listToMaybe . sourceRepos . snd
---- Collection:
getField (FieldName Nothing "flags")        = unlines' . map (getFlagField "name")  . genPackageFlags . fst
getField (FieldName Nothing "executables")  = unlines' . map (getExecutableField "name") . executables . snd
getField (FieldName Nothing "testsuites")   = unlines' . map (getTestSuiteField  "name") . testSuites . snd
getField (FieldName Nothing "benchmarks")   = unlines' . map (getBenchmarkField  "name") . benchmarks . snd
getField (FieldName Nothing "repositories") = unlines' . map (getSourceRepoField "name") . sourceRepos . snd
---- Other
getField (FieldName Nothing "main-is") = maybe "" (getExecutableField "main-is") . listToMaybe . executables . snd
getField (FieldName Nothing "upstream") = maybe "" (getSourceRepoField "location") . listToMaybe . filter ((RepoHead==) . repoKind) . sourceRepos . snd
-- Qualified Fields
getField (FieldName (Just name) field) = \(gpkg, pkg) ->
  let flag  = listToMaybe $ filter (\f -> map toLower ((unFlagName . flagName) f) == name) (genPackageFlags gpkg)
      exe   = listToMaybe $ filter (\e -> map toLower ((unUnqualComponentName . exeName)  e) == name) (executables pkg)
      test  = listToMaybe $ filter (\t -> map toLower ((unUnqualComponentName . testName) t) == name) (testSuites  pkg)
      bench = listToMaybe $ filter (\b -> map toLower ((unUnqualComponentName . benchmarkName) b) == name) (benchmarks pkg)
      repo  = listToMaybe $ filter (\r -> display (repoKind r) == name || (map toLower <$> repoTag r) == Just name) (sourceRepos pkg)
  in fromMaybe "" $
       (getFlagField       field <$> flag)  <|>
       (getExecutableField field <$> exe)   <|>
       (getTestSuiteField  field <$> test)  <|>
       (getBenchmarkField  field <$> bench) <|>
       (getSourceRepoField field <$> repo)
-- Catch-all
getField (FieldName Nothing field)
  | field `elem` packageDescriptionFields = getPackageDescriptionField field . snd

  | field `elem` libraryFields = maybe "" (getLibraryField field) . library . snd

  | field `elem` buildInfoFields = \(_, pkg) ->
    let lib = libBuildInfo <$> library pkg
        exe = buildInfo <$> listToMaybe (executables pkg)
    in maybe "" (getBuildInfoField field) (lib <|> exe)

  | otherwise = const ""

-- * 'PackageDescription'

-- | Get a field from a 'PackageDescription'.
getPackageDescriptionField :: String -> PackageDescription -> String
getPackageDescriptionField "extra-source-files" = unlines' . extraSrcFiles
getPackageDescriptionField "extra-doc-files" = unlines' . extraDocFiles
getPackageDescriptionField "extra-tmp-files" = unlines' . extraTmpFiles
getPackageDescriptionField "license-files" = unlines' . licenseFiles
getPackageDescriptionField "build-depends" = unlines' . map display . allBuildDepends
getPackageDescriptionField "license-file" = unlines' . licenseFiles
getPackageDescriptionField "package-url" = fromShortText . pkgUrl
getPackageDescriptionField "bug-reports" = fromShortText .bugReports
getPackageDescriptionField "description" = fromShortText .description
getPackageDescriptionField "tested-with" = unlines' . map (\(c, v) ->
                                                        display c ++ " " ++ display v) . testedWith
getPackageDescriptionField "data-files" = unlines' . dataFiles
getPackageDescriptionField "maintainer" = fromShortText .maintainer
getPackageDescriptionField "build-type" = unlines' . map display . maybeToList . buildTypeRaw
getPackageDescriptionField "copyright" = fromShortText .copyright
getPackageDescriptionField "stability" = fromShortText .stability
getPackageDescriptionField "data-dir" = dataDir
getPackageDescriptionField "homepage" = fromShortText .homepage
getPackageDescriptionField "synopsis" = fromShortText .synopsis
getPackageDescriptionField "category" = fromShortText .category
getPackageDescriptionField "version" = display . pkgVersion . package
getPackageDescriptionField "license" = display . license
getPackageDescriptionField "author" = fromShortText .author
getPackageDescriptionField "name" = unPackageName . pkgName . package
getPackageDescriptionField _ = const ""

-- | All the fields in a 'PackageDescription'.
packageDescriptionFields :: [String]
packageDescriptionFields = ["name"
                           , "version"
                           , "build-type"
                           , "build-depends"
                           , "license"
                           , "license-files"
                           , "copyright"
                           , "maintainer"
                           , "author"
                           , "stability"
                           , "homepage"
                           , "package-url"
                           , "bug-reports"
                           , "synopsis"
                           , "description"
                           , "category"
                           , "tested-with"
                           , "data-files"
                           , "data-dir"
                           , "extra-source-files"
                           , "extra-doc-files"
                           , "extra-tmp-files"]

-- * 'Flag'

-- | Get a field from a 'Flag'.
getFlagField :: String -> Flag -> String
getFlagField "description" = flagDescription
getFlagField "default"     = display . flagDefault
getFlagField "manual"      = display . flagManual
getFlagField "name"        = unFlagName . flagName
getFlagField _             = const ""

-- | All the fields in a 'Flag'.
flagFields :: [String]
flagFields = ["name", "description", "default", "manual"]

-- * 'SourceRepo'

-- | Get a field from a 'SourceRepo'.
getSourceRepoField :: String -> SourceRepo -> String
getSourceRepoField "name"     = display . repoKind
getSourceRepoField "type"     = maybe "" display . repoType
getSourceRepoField "location" = fromMaybe "" . repoLocation
getSourceRepoField "module"   = fromMaybe "" . repoModule
getSourceRepoField "branch"   = fromMaybe "" . repoBranch
getSourceRepoField "tag"      = fromMaybe "" . repoTag
getSourceRepoField "subdir"   = fromMaybe "" . repoSubdir
getSourceRepoField _          = const ""

-- | All the fields in a 'SourceRepo'.
sourceRepoFields :: [String]
sourceRepoFields = ["name", "type", "location", "module", "branch", "tag", "subdir"]

-- * 'Library'

-- | Get a field from a 'Library'.
getLibraryField :: String -> Library -> String
getLibraryField "exposed" = display . libExposed
getLibraryField "exposed-modules" = unlines' . map display . exposedModules
getLibraryField "reexported-modules" = unlines' . map display . reexportedModules
getLibraryField field = getBuildInfoField field . libBuildInfo

-- | All the fields from a 'Library'.
libraryFields :: [String]
libraryFields = ["exposed", "exposed-modules", "reexported-modules"]

-- * @Executable'

-- | Get a field from an 'Executable'.
getExecutableField :: String -> Executable -> String
getExecutableField "name"    = unUnqualComponentName . exeName
getExecutableField "main-is" = modulePath
getExecutableField field     = getBuildInfoField field . buildInfo

-- | All the fields in an 'Executable'.
executableFields :: [String]
executableFields = ["name", "main-is"]

-- * 'TestSuite'

-- | Get a field from a 'TestSuite'.
getTestSuiteField :: String -> TestSuite -> String
getTestSuiteField "name" = unUnqualComponentName . testName
getTestSuiteField "type" = get . testInterface where
  get (TestSuiteExeV10 _ _) = "exitcode-stdio-1.0"
  get (TestSuiteLibV09 _ _) = "detailed-0.9"
  get (TestSuiteUnsupported (TestTypeExe v)) = "exitcode-stdio-" ++ display v
  get (TestSuiteUnsupported (TestTypeLib v)) = "detailed-" ++ display v
  get (TestSuiteUnsupported (TestTypeUnknown s v)) = s ++ "-" ++ display v
getTestSuiteField "main-is" = get . testInterface where
  get (TestSuiteExeV10 _ f) = f
  get _                     = ""
getTestSuiteField "test-module" = get . testInterface where
  get (TestSuiteLibV09 _ m) = display m
  get _                     = ""
getTestSuiteField field = getBuildInfoField field . testBuildInfo

-- | All the fields in a 'TestSuite'.
testSuiteFields :: [String]
testSuiteFields = ["name", "type", "main-is", "test-module", "enabled"]

-- * 'Benchmark'

-- | Get a field from a 'Benchmark'.
getBenchmarkField :: String -> Benchmark -> String
getBenchmarkField "name" = unUnqualComponentName . benchmarkName
getBenchmarkField "type" = get . benchmarkInterface where
  get (BenchmarkExeV10 _ _) = "exitcode-stdio-1.0"
  get (BenchmarkUnsupported (BenchmarkTypeExe v)) = "exitcode-stdio-" ++ display v
  get (BenchmarkUnsupported (BenchmarkTypeUnknown s v)) = s ++ "-" ++ display v
getBenchmarkField "main-is" = get . benchmarkInterface where
  get (BenchmarkExeV10 _ f) = f
  get _                     = ""
getBenchmarkField field = getBuildInfoField field . benchmarkBuildInfo

-- | All the fields in a 'Benchmark'.
benchmarkFields :: [String]
benchmarkFields = ["name", "type", "main-is", "enabled"]

-- * 'BuildInfo'

-- | Get a field from some 'BuildInfo'.
getBuildInfoField :: String -> BuildInfo -> String
getBuildInfoField field = unlines' . get field where
  get "extra-libraries"      = extraLibs
  get "extra-ghci-libraries" = extraGHCiLibs
  get "extra-lib-dirs"       = extraLibDirs
  get "extensions"         = map display . oldExtensions
  get "default-extensions" = map display . defaultExtensions
  get "other-extensions"   = map display . otherExtensions
  get "ghc-options"        = concatMap snd . filter ((==GHC) . fst) . perCompilerFlavorToList . options
  get "ghc-prof-options"   = concatMap snd . filter ((==GHC) . fst) . perCompilerFlavorToList . profOptions
  get "ghc-shared-options" = concatMap snd . filter ((==GHC) . fst) . perCompilerFlavorToList. sharedOptions
  get "pkgconfig-depends"  = map display . pkgconfigDepends
  get "install-includes"   = installIncludes
  get "hs-source-dirs" = hsSourceDirs
  get "build-depends"  = map display . targetBuildDepends
  get "other-modules"  = map display . otherModules
  get "include-dirs"   = includeDirs
  get "build-tools" = map display . buildTools
  get "cc-options"  = ccOptions
  get "cpp-options" = cppOptions
  get "ld-options"  = ldOptions
  get "c-sources"  = cSources
  get "js-sources" = jsSources
  get "frameworks" = frameworks
  get "buildable"  = (:[]) . display . buildable
  get "includes" = includes
  get _ = const []

-- | All the fields in a 'BuildInfo'
buildInfoFields :: [String]
buildInfoFields = ["build-depends"
                  , "other-modules"
                  , "hs-source-dirs"
                  , "extensions"
                  , "default-extensions"
                  , "other-extensions"
                  , "build-tools"
                  , "buildable"
                  , "ghc-options"
                  , "ghc-prof-options"
                  , "ghc-shared-options"
                  , "includes"
                  , "install-includes"
                  , "include-dirs"
                  , "c-sources"
                  , "js-sources"
                  , "extra-libraries"
                  , "extra-ghci-libraries"
                  , "extra-lib-dirs"
                  , "cc-options"
                  , "ld-options"
                  , "pkgconfig-depends"
                  , "frameworks"]

-- * Utilities

-- | Like 'unlines', but don't include the trailing newline.
unlines' :: [String] -> String
unlines' = init' . unlines where
  init' [] = []
  init' xs = init xs
