;;; portfile.el --- Major mode for editing MacPorts Portfiles  -*- lexical-binding: t; -*-

;; Copyright (C) 2015  Chunyang Xu

;; Author: Chunyang Xu <chunyang@macports.org>
;; URL: https://trac.macports.org/browser/branches/gsoc15-portfile/portfile.el/
;; Version: 0.0.1
;; Created: Tue Jun  9 03:14:33 CST 2015
;; Keywords: MacPorts Portfile

;;; Commentary:

;;

;;; Code:

(defvar portfile-required-list
  '("PortSystem" "name" "version" "maintainers"
    "homepage" "platforms"
    "master_sites" "master_sites-append" "master_sites-delete"
    "categories" "categories-append" "categories-delete"
    "description" "description-append"
    "long_description" "long_description-append"))

(defvar portfile-optional-list
  '("PortGroup" "epoch" "revision" "patch_sites"
    "license" "conflicts" "license_noconflict"
    "replaced_by" "supported_archs"
    "distfiles" "distfiles-append" "distfiles-delete"
    "distname" "dist_subdir" "worksrcdir"
    "installs_libs" "nextgroup=PortfileYesNo" "skipwhite"
    "depends_skip_archcheck" "depends_skip_archcheck-append" "depends_skip_archcheck-delete"
    "checksums" "checksums-append" "checksums-delete"))

(defvar portfile-mode-font-lock-keywords
  (list (cons (concat "\\_<"
                      (regexp-opt (append portfile-required-list
                                          portfile-optional-list) t) "\\_>")
              'font-lock-keyword-face)))

(define-derived-mode portfile-mode tcl-mode "portfile-mode"
  "Portfile mode"
  (font-lock-add-keywords nil portfile-mode-font-lock-keywords))

;; Test:
;; (add-hook 'tcl-mode-hook (lambda ()
;;                            (when (string-equal (buffer-name) "Portfile")
;;                              (portfile-mode))))

(provide 'portfile)
;;; portfile.el ends here
