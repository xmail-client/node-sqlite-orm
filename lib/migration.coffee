_ = require 'underscore'

class TableInfo
  constructor: (@tableName) ->
    @attributes = {}

  addColumn: (name, type, opts) ->
    @attributes[name] = if opts then _.extend({type}, opts) else {type}
    @primaryKeyName = name if opts?.primaryKey

  addIndex: (names...) ->
    @attributes[name].index = true for name in names

  addReference: (name, tableName, opts={}) ->
    opts.fields ?= Migration.tables[tableName].primaryKeyName
    @attributes[name].references = _.extend {name: tableName}, opts

module.exports =
class Migration
  @tables = {}

  @createTable: (tableName, callback) ->
    tableInfo = new TableInfo(tableName)
    callback(tableInfo)
    @tables[tableName] = tableInfo
