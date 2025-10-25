;; title: Bible-app
;; version: 1.0.0
;; summary: A simple Bible app
;; description: This is a simple Bible app that allows users to read and search the Bible.

;; bibleprayer-app

(define-data-var reminder-counter uint u0)

(define-map reminders
    { id: uint }
    {
        user: principal,
        verse: (string-ascii 50),
        prayer: (string-ascii 50),
        status: (string-ascii 10),
    }
)

;; Create a Bible verse and prayer reminder
(define-public (create-reminder
        (verse (string-ascii 50))
        (prayer (string-ascii 50))
    )
    (begin
        (asserts! (> (len verse) u0) (err u1))
        (asserts! (> (len prayer) u0) (err u2))
        (let ((id (var-get reminder-counter)))
            (map-set reminders { id: id } {
                user: tx-sender,
                verse: verse,
                prayer: prayer,
                status: "active",
            })
            (var-set reminder-counter (+ id u1))
            (ok id)
        )
    )
)

;; Mark reminder as read
(define-public (mark-read (id uint))
    (match (map-get? reminders { id: id })
        reminder
        (if (and (is-eq (get status reminder) "active") (is-eq tx-sender (get user reminder)))
            (begin
                (map-set reminders { id: id } {
                    user: (get user reminder),
                    verse: (get verse reminder),
                    prayer: (get prayer reminder),
                    status: "read",
                })
                (ok "Reminder read")
            )
            (err u3)
        )
        ;; not active or not user
        (err u4)
    )
    ;; reminder not found
)

;; Archive a reminder
(define-public (archive-reminder (id uint))
    (match (map-get? reminders { id: id })
        reminder
        (if (and (is-eq (get status reminder) "read") (is-eq tx-sender (get user reminder)))
            (begin
                (map-set reminders { id: id } {
                    user: (get user reminder),
                    verse: (get verse reminder),
                    prayer: (get prayer reminder),
                    status: "archived",
                })
                (ok "Reminder archived")
            )
            (err u5)
        )
        ;; not read or not user
        (err u6)
    )
    ;; reminder not found
)