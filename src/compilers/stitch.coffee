fs = require 'fs'
path = require 'path'
stitch = require 'stitch'
uglify = require 'uglify-js'

helpers = require '../helpers'
{Compiler} = require './base'


class exports.StitchCompiler extends Compiler
  patterns: ->
    [/(app|vendor)\/.*\.(js|coffee)$/, ///#{@options.templateExtension}$///]

  collect: (type) ->
    directory = @getRootPath type
    fileNames = helpers.filterFiles (fs.readdirSync directory), directory
    if type is 'vendor'
      # Generate list of dependencies and preserve order of brunch libaries,
      # like defined in options.dependencies.
      fileNames = @options.dependencies.concat fileNames.filter (fileName) =>
        fileName not in @options.dependencies
    fileNames.map (fileName) => path.join directory, fileName

  package: ->
    @_package ?= stitch.createPackage
      dependencies: @collect 'vendor'
      paths: [@getRootPath 'app']

  minify: (source) ->
    {parse} = uglify.parser
    {ast_mangle, ast_squeeze, gen_code} = uglify.uglify
    @log 'minified'
    gen_code ast_squeeze ast_mangle parse source

  compile: (files, callback) ->
    # update package dependencies in case a dependency was added or removed
    if files.some((file) -> file.match /vendor\//)
      @package().dependencies = @collect 'vendor'

    @package().compile (error, source) =>
      return @logError error if error?
      @log()
      source = @minify source if @options.minify
      outPath = @getBuildPath path.join 'scripts', 'app.js'
      fs.writeFile outPath, source, (error) =>
        return @logError "couldn't write compiled file. #{error}" if error?
        callback @getClassName()
