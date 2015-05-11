Q = require 'q'
QueryGenerator = require './query-generator'

module.exports =
class Query
  constructor: (@db) ->

  createTable: (tableName, attrs) ->
    Q.ninvoke @db, 'run', QueryGenerator.createTableStmt(tableName, attrs)

  insert: (tableName, fields) ->
    defer = Q.defer()
    @db.run QueryGenerator.insertStmt(tableName, fields), (err) ->
      if err then defer.reject(err) else defer.resolve(this.lastID)
    defer.promise

  update: (tableName, fields, where) ->
    Q.ninvoke @db, 'run', QueryGenerator.updateStmt(tableName, fields, where)

  select: (tableName, where, opts) ->
    Q.ninvoke @db, 'all', QueryGenerator.selectStmt(tableName, where, opts)

  selectOne: (tableName, where, opts) ->
    Q.ninvoke @db, 'get', QueryGenerator.selectStmt(tableName, where, opts)

  dropTable: (tableName) ->
    Q.ninvoke @db, 'run', QueryGenerator.dropTableStmt(tableName)
