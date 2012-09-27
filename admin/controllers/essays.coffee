Spine       = require('spine/core')
# $           = Spine.$
templates   = require('duality/templates')

MultiSelectUI = require('controllers/ui/multi-select')
FileUploadUI  = require('controllers/ui/file-upload')

Essay       = require('models/essay')
Author      = require('models/author')
Collection  = require('models/collection')
Sponsor     = require('models/sponsor')
Site        = require('models/site')


class EssayForm extends Spine.Controller
  className: 'essay form panel'

  elements:
    '.item-title':             'itemTitle'
    '.error-message':          'errorMessage'
    'form':                    'form'
    'select[name=site]':       'formSite'
    'select[name=author_id]':  'formAuthorId'
    'select[name=sponsor_id]': 'formSponsorId'
    '.collections-list':       'collectionsList'
    '.files-list':             'filesList'
    '.save-button':            'saveButton'
    '.cancel-button':          'cancelButton'

  events:
    'submit form':              'preventSubmit'
    'click .save-button':       'save'
    'click .cancel-button':     'cancel'
    'click .delete-button':     'destroy'
    'change select[name=site]': 'siteChange'

  constructor: ->
    super
    @active @render

  render: (params) ->
    @editing = params.id?
    if @editing
      @copying = params.id.split('-')[0] is 'copy'
      if @copying
        @title = 'Copy Essay'
        @item = Essay.find(params.id.split('-')[1]).dup()
      else
        @item = Essay.find(params.id)
        @title = @item.name
    else
      @title = 'New Essay'
      @item = {}

    @item.collections ?= []
    @item._attachments ?= {}
    
    @item.sites = Site.all().sort(Site.nameSort)
    @item.sponsors = Sponsor.all().sort(Sponsor.nameSort)
    @html templates.render('essay-form.html', {}, @item)

    @itemTitle.html @title
    
    # Set few initial form values
    if @editing
      @formSite.val(@item.site)
      @formSponsorId.val(@item.sponsor_id)
    else
      @formSite.val(@stack.stack.filterBox.siteId)
    @siteChange()

    # Files upload area
    @fileUpload = new FileUploadUI
      docId: @item.id
      attachments: @item._attachments
    @filesList.find('.upload-ui').html @fileUpload.el

  siteChange: ->
    $siteSelected = @formSite.parents('.field').find('.site-selected')
    site = Site.exists(@formSite.val())
    if site
      $siteSelected.html "<div class=\"site-name theme-#{site.theme}\">#{site.name_html}</div>"
      @makeAuthorsList(site)
      @makeCollectionsList(site)
    else
      $siteSelected.html ""

  makeAuthorsList: (site) ->
    authors = Author.findAllByAttribute('site', site.id)
    @formAuthorId.empty()
      .append "<option value=\"\">Select an author...</option>"
    for author in authors
      @formAuthorId.append "<option value=\"#{author.id}\">#{author.name}</option>"
    @formAuthorId.val(@item.author_id)
  
  makeCollectionsList: (site) ->
    collections = Collection.findAllByAttribute('site', site.id)
    @collectionSelect = new MultiSelectUI
      items: collections
      selectedItems: (c.id for c in @item.collections)
      valueFields: ['id','slug']
    @collectionsList.html @collectionSelect.el

  save: (e) ->
    e.preventDefault()
    if @editing
      @item.fromForm(@form)
    else
      @item = new Essay().fromForm(@form)

    # Convert some boolean properties
    @item.published = Boolean(@item.published)

    @item.collections = @collectionSelect.selected()

    # TODO: Take care of files and photo
    @item._attachments = @fileUpload.attachments
    @item.photo = null

    # Take care of some dates if need be
    try
      if @item.published_at
        @item.published_at = new Date(@item.published_at).toJSON()
      else
        @item.published_at = new Date().toJSON()
    catch error
      @showError "Date format is wrong. Use this format: 'Feb 20 2012 6:30 PM'"
    
    # Save the item and make sure it validates
    if @item.save()
      @back()
    else
      msg = @item.validate()
      @showError msg

  showError: (msg) ->
    @errorMessage.html(msg).show()
    @el.scrollTop(0, 0)
  
  destroy: (e) ->
    e.preventDefault()
    if @item and confirm "Are you sure you want to delete this #{@item.constructor.name}?"
      @item.destroy()
      @back()

  cancel: (e) ->
    e.preventDefault()
    if @dirtyForm
      if confirm "You may have some unsaved changes.\nAre you sure you want to cancel?"
        @back()
    else
      @back()

  back: ->
    @navigate('/essays/list')

  preventSubmit: (e) ->
    e.preventDefault()
    
  deactivate: ->
    super
    @el.scrollTop(0, 0)


class EssayList extends Spine.Controller
  className: 'essay list panel'

  constructor: ->
    super
    # @active @render
    Essay.bind 'change refresh', @render
    Spine.bind 'filterbox:change', @filter

  render: =>
    context = 
      essays: Essay.filter(@filterObj).sort(Essay.titleSort)
    @el.html templates.render('essays.html', {}, context)
    @

  filter: (@filterObj) =>
    @render()


class Essays extends Spine.Stack
  className: 'essays panel'

  controllers:
    list: EssayList
    form: EssayForm

  default: 'list'

  routes:
    '/essays/list': 'list'
    '/essay/new':   'form'
    '/essay/:id':   'form'


module.exports = Essays