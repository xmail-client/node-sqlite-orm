Mixin = require 'mixto'
_ = require 'underscore'
Q = require 'q'
ModelAssociation = require './model-association'

module.exports =
class ModelBaseMixin extends Mixin
  ModelAssociation.includeInto this
  @models = {}

  initModel: (params) ->
    @isInsert = false
    @changeFields = {}
    @query = @constructor.query
    this[key] = val for key, val of params

  @included: ->
    ModelBaseMixin.models[this.name] = this if this.name
    @_initAssos()

  @defineAttr: (name, opts) ->
    key = '_' + name
    opts.default ?= null
    Object.defineProperty @prototype, name,
      get: -> this[key] ? opts.default
      set: (val) ->
        this[key] = val
        @changeFields[name] = val

  # apply tableInfo's attributes into the Model's prototype,
  # so that the model has the db column variables
  @extendAttrs: (tableInfo) ->
    for name, opts of tableInfo.attributes when not @::hasOwnProperty(name)
      @defineAttr name, opts

  @extendModel: (mapper, tableInfo) ->
    @mapper = mapper
    @query = mapper.getQuery()
    @cache = mapper.cache
    @tableName = tableInfo.tableName
    @primaryKeyName = tableInfo.primaryKeyName
    @extendAttrs tableInfo

  @getMapper: -> @mapper

  @wrapWhere: (where) ->
    if where and not _.isObject where
      where = {"#{@primaryKeyName}": where}
    where

  getIdFromWhere = (where) ->
    return where unless _.isObject(where)
    keys = _.keys(where)
    if keys.length is 1 and keys[0] is @primaryKeyName
      keys[0]

  @find: (where, opts={}) ->
    if (primaryVal = getIdFromWhere.call(this, where))?
      @getById(primaryVal)
    else
      opts.limit = 1
      @query.selectOne(@tableName, @wrapWhere(where), opts).then (res) =>
        if res then @load(res) else null

  @findAll: (where, opts) ->
    @query.select(@tableName, @wrapWhere(where), opts).then (results) =>
      promises = for res in results
        @load(res)
      Q.all promises

  @each: (where, opts, step) ->
    if _.isFunction(where)
      step = where
      where = opts = null
    else if _.isFunction(opts)
      step = opts
      opts = null
    @query.selectEach(@tableName, @wrapWhere(where), opts, step)

  save: ->
    Constructor = @constructor
    keyName = Constructor.primaryKeyName
    tableName = Constructor.tableName
    unless @isInsert
      @query.insert(tableName, @changeFields).then (rowId) =>
        this[keyName] = rowId
        @changeFields = {}
        Model = @constructor
        Model.cache.set Model.generateCacheKey(rowId), this
        @isInsert = true
        # Model.loadAssos(this)
    else if _.keys(@changeFields).length is 0
      Q()
    else
      where = "#{keyName}": this[keyName]
      @query.update(tableName, @changeFields, where).then =>
        @changeFields = {}

  destroy: ->
    @destroyAssos()
    Constructor = @constructor
    keyName = Constructor.primaryKeyName
    @query.remove(Constructor.tableName, "#{keyName}": this[keyName])

  @clear: ->
    @query.remove(@tableName)

  @generateCacheKey: (id) -> @tableName + '@' + id

  @getById: (id) ->
    key = @generateCacheKey(id)
    if (model = @cache.get(key))?
      Q(model)
    else
      @query.selectOne(@tableName, @wrapWhere(id)).then (res) =>
        if res then @loadNoCache(res) else null

  @loadNoCache: (obj) ->
    model = new this
    model['_' + key] = val for key, val of obj
    model.isInsert = true

    primaryVal = obj[@primaryKeyName]
    @cache.set @generateCacheKey(primaryVal), model
    @loadAssos(model).then -> model

  @load: (obj) ->
    primaryVal = obj[@primaryKeyName]
    cacheKey = @generateCacheKey(primaryVal)
    if (model = @cache.get(cacheKey))?
      Q(model)
    else
      @loadNoCache(obj)

  @new: (obj) ->
    new this(obj)

  @create: (obj) ->
    model = new this(obj)
    model.save().then -> model

  @drop: ->
    delete @models[@name]
    @query.dropTable @tableName
