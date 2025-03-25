/** @odoo-module **/

import { Wysiwyg } from '@web_editor/js/wysiwyg/wysiwyg';
import { patch } from '@web/core/utils/patch';
import { _t } from '@web/core/l10n/translation';
import { OdooEditor } from '@web_editor/js/editor/odoo-editor/src/OdooEditor';


patch(Wysiwyg.prototype, {

    /**
     * Override of the 'configureToolbar' method to ensure that the alignment
     * buttons are not removed from the tollbar in the web editor
     */
    _configureToolbar(options) {
        const $toolbar = $(this.toolbarEl);
        // Prevent selection loss when interacting with the toolbar buttons.
        $toolbar.find('.btn-group').on('mousedown', e => {
            if (
                // Prevent when clicking on btn-group but not on dropdown items.
                !e.target.closest('.dropdown-menu') ||
                // Unless they have a data-call in which case there is an editor
                // command that is bound to it so we need to preventDefault.
                e.target.closest('.btn') && e.target.closest('.btn').getAttribute('data-call')
            ) {
                e.preventDefault();
            }
        });
        const openTools = e => {
            e.preventDefault();
            e.stopImmediatePropagation();
            e.stopPropagation();
            switch (e.currentTarget.id) {
                case 'create-link':
                    this.toggleLinkTools();
                    break;
                case 'media-insert':
                case 'media-replace':
                    this.openMediaDialog({ node: this.lastMediaClicked });
                    break;
                case 'media-description': {
                    const allEscQuots = /&quot;/g;
                    const alt = ($(this.lastMediaClicked).attr('alt') || "").replace(allEscQuots, '"');
                    const tag_title = (
                        $(this.lastMediaClicked).attr('title') ||
                        $(this.lastMediaClicked).data('original-title') ||
                        ""
                    ).replace(allEscQuots, '"');

                    this.env.services.dialog.add(AltDialog, {
                        alt,
                        tag_title,
                        confirm: (newAlt, newTitle) => {
                            if (newAlt) {
                                this.lastMediaClicked.setAttribute('alt', newAlt);
                            } else {
                                this.lastMediaClicked.removeAttribute('alt');
                            }
                            if (newTitle) {
                                this.lastMediaClicked.setAttribute('title', newTitle);
                            } else {
                                this.lastMediaClicked.removeAttribute('title');
                            }
                        },
                    });
                    break;
                }
                case 'open-chatgpt': {
                    this.openChatGPTDialog(this.odooEditor.document.getSelection()?.isCollapsed ? 'prompt' : 'alternatives');
                    break;
                }
            }
        };
        if (!options.snippets) {
            $toolbar.find('#media-insert').remove();
        }
        $toolbar.find('#image-fullscreen').click(() => {
            if (!this.lastMediaClicked?.src) {
                return;
            }
            this.showImageFullscreen(this.lastMediaClicked.src);
        })
        $toolbar.find('#media-insert, #media-replace, #media-description').click(openTools);
        $toolbar.find('#create-link').click(openTools);
        $toolbar.find('#open-chatgpt').click(openTools);
        $toolbar.find('#image-shape div, #fa-spin').click(e => {
            if (!this.lastMediaClicked) {
                return;
            }
            this.lastMediaClicked.classList.toggle(e.target.id);
            e.target.classList.toggle('active', $(this.lastMediaClicked).hasClass(e.target.id));
        });
        const $imageWidthButtons = $toolbar.find('#image-width div');
        $imageWidthButtons.click(e => {
            if (!this.lastMediaClicked) {
                return;
            }
            this.lastMediaClicked.style.width = e.target.id;
            for (const button of $imageWidthButtons) {
                button.classList.toggle('active', this.lastMediaClicked.style.width === button.id);
            }
        });
        $toolbar.find('#image-padding .dropdown-item').click(e => {
            if (!this.lastMediaClicked) {
                return;
            }
            $(this.lastMediaClicked).removeClass((index, className) => (
                (className.match(/(^|\s)padding-\w+/g) || []).join(' ')
            )).addClass(e.target.dataset.class);
        });
        $toolbar.on('mousedown', e => {
            const justifyBtn = e.target.closest('#justify div.btn');
            if (!justifyBtn || !this.lastMediaClicked) {
                return;
            }
            e.originalEvent.stopImmediatePropagation();
            e.originalEvent.stopPropagation();
            e.originalEvent.preventDefault();
            const mode = justifyBtn.id.replace('justify', '').toLowerCase();
            const classes = mode === 'center' ? ['d-block', 'mx-auto'] : ['float-' + mode];
            const doAdd = classes.some(className => !this.lastMediaClicked.classList.contains(className));
            this.lastMediaClicked.classList.remove('float-start', 'float-end');
            if (this.lastMediaClicked.classList.contains('mx-auto')) {
                this.lastMediaClicked.classList.remove('d-block', 'mx-auto');
            }
            if (doAdd) {
                this.lastMediaClicked.classList.add(...classes);
            }
            this._updateMediaJustifyButton(justifyBtn.id);
        });
        $toolbar.find('#image-crop').click(() => this._showImageCrop());
        $toolbar.find('#image-transform').click(e => {
            const sel = document.getSelection();
            sel.removeAllRanges();
            if (!this.lastMediaClicked) {
                return;
            }
            const $image = $(this.lastMediaClicked);
            if ($image.data('transfo-destroy')) {
                $image.removeData('transfo-destroy');
                return;
            }
            $image.transfo({ document: this.odooEditor.document });
            const destroyTransfo = () => {
                $image.transfo('destroy');
                $(this.odooEditor.document).off('mousedown', mousedown).off('mouseup', mouseup);
                this.odooEditor.document.removeEventListener('keydown', keydown);
            }
            const mouseup = () => {
                $('#image-transform').toggleClass('active', $image.is('[style*="transform"]'));
            };
            $(this.odooEditor.document).on('mouseup', mouseup);
            const mousedown = mousedownEvent => {
                if (!$(mousedownEvent.target).closest('.transfo-container').length) {
                    destroyTransfo();
                }
                if ($(mousedownEvent.target).closest('#image-transform').length) {
                    $image.data('transfo-destroy', true).attr('style', ($image.attr('style') || '').replace(/[^;]*transform[\w:]*;?/g, ''));
                }
                $image.trigger('content_changed');
            };
            $(this.odooEditor.document).on('mousedown', mousedown);
            const keydown = keydownEvent => {
                if (keydownEvent.key === 'Escape') {
                    keydownEvent.stopImmediatePropagation();
                    destroyTransfo();
                }
            };
            this.odooEditor.document.addEventListener('keydown', keydown);
        });
        $toolbar.find('#image-delete').click(e => {
            if (!this.lastMediaClicked) {
                return;
            }
            $(this.lastMediaClicked).remove();
            this.lastMediaClicked = undefined;
            this.odooEditor.toolbarHide();
        });
        $toolbar.find('#fa-resize div').click(e => {
            if (!this.lastMediaClicked) {
                return;
            }
            const $target = $(this.lastMediaClicked);
            const sValue = e.target.dataset.value;
            $target.attr('class', $target.attr('class').replace(/\s*fa-[0-9]+x/g, ''));
            if (+sValue > 1) {
                $target.addClass('fa-' + sValue + 'x');
            }
            this._updateFaResizeButtons();
        });
        if (!options.snippets) {
            // Scroll event does not bubble.
            document.addEventListener('scroll', this._onScroll, true);
        }
    },

    _getPowerboxOptions() {
        const options = super._getPowerboxOptions();
        const wysiwyg = this;


        // Define alignment commands using oAlign
        const alignmentCommands = [
            {
                name: _t('Align text left'),
                category: _t('Structure'),
                description: _t('Align text to the left'),
                fontawesome: 'fa-align-left',
                priority: 4,
                callback: () => {
                    const selection = wysiwyg.odooEditor.document.getSelection();
                    if (selection && selection.anchorNode) {
                        selection.anchorNode.parentElement.oAlign(selection.anchorOffset, 'left');
                    }
                },
            },
            {
                name: _t('Align text center'),
                category: _t('Structure'),
                description: _t('Center align text'),
                fontawesome: 'fa-align-center',
                priority: 3,
                callback: () => {
                    const selection = wysiwyg.odooEditor.document.getSelection();
                    if (selection && selection.anchorNode) {
                        selection.anchorNode.parentElement.oAlign(selection.anchorOffset, 'center');
                    }
                },
            },
            {
                name: _t('Align text right'),
                category: _t('Structure'),
                description: _t('Align text to the right'),
                fontawesome: 'fa-align-right',
                priority: 2,
                callback: () => {
                    const selection = wysiwyg.odooEditor.document.getSelection();
                    if (selection && selection.anchorNode) {
                        selection.anchorNode.parentElement.oAlign(selection.anchorOffset, 'right');
                    }
                },
            },
            {
                name: _t('Justify text'),
                category: _t('Structure'),
                description: _t('Justify text'),
                fontawesome: 'fa-align-justify',
                priority: 1,
                callback: () => {
                    const selection = wysiwyg.odooEditor.document.getSelection();
                    if (selection && selection.anchorNode) {
                        selection.anchorNode.parentElement.oAlign(selection.anchorOffset, 'justify');
                    }
                },
            },
        ];
        // Add alignment commands to options
        options.commands.push(...alignmentCommands);

        return options;
    },

});


patch(OdooEditor.prototype, {

    _onKeyDown(event) {
        super._onKeyDown(event);
        // Check if Ctrl+Shift is pressed
        if (event.ctrlKey && event.shiftKey) {
            const selection = this.document.getSelection();
            if (!selection || !selection.anchorNode) {
                return; // No selection, do nothing
            }

            const parentElement = selection.anchorNode.parentElement;

            // Handle specific key combinations
            switch (event.key.toLowerCase()) {
                case 'l': // Ctrl+Shift+L -> Align Left
                    parentElement.oAlign(selection.anchorOffset, 'left');
                    event.preventDefault();
                    return;
                case 'c': // Ctrl+Shift+C -> Align Center
                    parentElement.oAlign(selection.anchorOffset, 'center');
                    event.preventDefault();
                    return;
                case 'r': // Ctrl+Shift+R -> Align Right
                    parentElement.oAlign(selection.anchorOffset, 'right');
                    event.preventDefault();
                    return;
                case 'j': // Ctrl+Shift+J -> Align Justify
                    parentElement.oAlign(selection.anchorOffset, 'justify');
                    event.preventDefault();
                    return;
            }
        }
    },
});