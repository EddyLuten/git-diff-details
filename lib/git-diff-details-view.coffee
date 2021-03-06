{View} = require 'atom'
Highlights = require 'highlights'
DiffDetailsDataManager = require './data-manager'
Housekeeping = require './housekeeping'

module.exports = class AtomGitDiffDetailsView extends View
  Housekeeping.includeInto(this)

  @content: ->
    @div class: "git-diff-details-outer", =>
      @div class: "git-diff-details-main-panel", outlet: "mainPanel", =>
        @div class: "editor", outlet: "contents"
      @div class: "git-diff-details-button-panel", outlet: "buttonPanel", =>
        @button class: 'btn btn-primary inline-block-tight', click: "copy", 'Copy'
        @button class: 'btn btn-error inline-block-tight', click: "undo", 'Undo'

  initialize: (@editorView) ->
    {@editor} = @editorView

    @initializeHousekeeping()
    @preventFocusOut()

    @highlighter = new Highlights()
    @diffDetailsDataManager = new DiffDetailsDataManager()

    @showDiffDetails = false
    @lineDiffDetails = null

    @updateCurrentRow()

  preventFocusOut: ->
    @buttonPanel.on 'mousedown', () ->
      false

    @mainPanel.on 'mousedown', () ->
      false

  notifyContentsModified: =>
    return if @editor.isDestroyed()
    @diffDetailsDataManager.invalidate(atom.project.getRepo(),
                                       @buffer.getPath(),
                                       @buffer.getText())
    if @showDiffDetails
      @updateDiffDetailsDisplay()

  toggleShowDiffDetails: ->
    @showDiffDetails = !@showDiffDetails
    @updateDiffDetails()

  closeDiffDetails: ->
    @showDiffDetails = false
    @updateDiffDetails()

  updateDiffDetails: ->
    @diffDetailsDataManager.invalidatePreviousSelectedHunk()
    @updateCurrentRow()
    @updateDiffDetailsDisplay()

  removeDecorations: ->

  notifyChangeCursorPosition: ->
    if @showDiffDetails
      currentRowChanged = @updateCurrentRow()
      @updateDiffDetailsDisplay() if currentRowChanged

  attach: ->
    @editorView.appendToLinesView(this)

  setPosition: (top) ->
    {left, top} = @editorView.pixelPositionForBufferPosition(row: top - 1, col: 0)
    @css(top: top + @editorView.lineHeight)

  populate: (selectedHunk) ->
    html = @highlighter.highlightSync
      filePath: @buffer.getBaseName()
      fileContents: selectedHunk.oldString

    html = html.replace('<pre class="editor editor-colors">', '').replace('</pre>', '')
    @contents.html(html)
    @contents.css(height: selectedHunk.oldLines.length * @editorView.lineHeight)

  copy: (e) ->
    {selectedHunk} = @diffDetailsDataManager.getSelectedHunk(@currentRow)
    atom.clipboard.write(selectedHunk.oldString)

  undo: (e) ->
    {selectedHunk} = @diffDetailsDataManager.getSelectedHunk(@currentRow)

    if buffer = @editor.getBuffer()
      if selectedHunk.kind is "m"
        buffer.deleteRows(selectedHunk.start - 1, selectedHunk.end - 1)
        buffer.insert([selectedHunk.start - 1, 0], selectedHunk.oldString)
      else
        buffer.insert([selectedHunk.start, 0], selectedHunk.oldString)

  getActiveTextEditor: ->
    atom.workspace.getActiveTextEditor()

  updateDiffDetailsDisplay: ->
    if @showDiffDetails
      {selectedHunk, isDifferent} = @diffDetailsDataManager.getSelectedHunk(@currentRow)

      if selectedHunk?
        return unless isDifferent
        @attach()
        @setPosition(selectedHunk.end)
        @populate(selectedHunk)
        return

      @previousSelectedHunk = selectedHunk

    @detach()
    return

  updateCurrentRow: ->
    newCurrentRow = @getActiveTextEditor()?.getCursorBufferPosition()?.row + 1
    if newCurrentRow != @currentRow
      @currentRow = newCurrentRow
      return true
    return false
