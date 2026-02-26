pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string filePath: Quickshell.env("XDG_DATA_HOME") + "/quickshell/events.json"
    property var list: []
    property int nextId: 1
    
    signal eventAdded(var event)
    signal eventRemoved(int id)
    signal eventUpdated(var event)
    signal eventTriggered(var event)

    Component.onCompleted: {
        loadFromFile()
        checkTimer.start()
    }

    // Check for due events every minute
    Timer {
        id: checkTimer
        interval: 60000 // 1 minute
        running: false
        repeat: true
        onTriggered: root.checkDueEvents()
    }

    function checkDueEvents() {
        const now = new Date()
        const currentTime = now.getTime()
        
        for (let i = 0; i < root.list.length; i++) {
            const event = root.list[i]
            if (!event.notified && event.dateTime) {
                const eventTime = new Date(event.dateTime).getTime()
                
                // Trigger if event time has passed
                if (currentTime >= eventTime) {
                    root.list[i].notified = true
                    root.eventTriggered(event)
                    root.saveToFile()
                }
            }
        }
    }

    function addEvent(title, description, dateTime, category, priority) {
        const event = {
            id: root.nextId++,
            title: title || "",
            description: description || "",
            dateTime: dateTime || new Date().toISOString(),
            category: category || "general", // general, birthday, meeting, deadline, reminder
            priority: priority || "normal", // low, normal, high
            notified: false,
            createdAt: new Date().toISOString()
        }
        
        root.list.push(event)
        root.list = root.list // Trigger binding update
        root.eventAdded(event)
        root.saveToFile()
        return event
    }

    function removeEvent(id) {
        const index = root.list.findIndex(e => e.id === id)
        if (index !== -1) {
            root.list.splice(index, 1)
            root.list = root.list
            root.eventRemoved(id)
            root.saveToFile()
            return true
        }
        return false
    }

    function updateEvent(id, updates) {
        const index = root.list.findIndex(e => e.id === id)
        if (index !== -1) {
            root.list[index] = Object.assign({}, root.list[index], updates)
            root.list = root.list
            root.eventUpdated(root.list[index])
            root.saveToFile()
            return true
        }
        return false
    }

    function getEventsForDate(date) {
        const targetDate = new Date(date)
        targetDate.setHours(0, 0, 0, 0)
        const nextDay = new Date(targetDate)
        nextDay.setDate(nextDay.getDate() + 1)
        
        return root.list.filter(event => {
            const eventDate = new Date(event.dateTime)
            eventDate.setHours(0, 0, 0, 0)
            return eventDate.getTime() === targetDate.getTime()
        })
    }

    function getUpcomingEvents(days) {
        const now = new Date()
        const future = new Date()
        future.setDate(future.getDate() + (days || 7))
        
        return root.list.filter(event => {
            const eventDate = new Date(event.dateTime)
            return eventDate >= now && eventDate <= future && !event.notified
        }).sort((a, b) => new Date(a.dateTime) - new Date(b.dateTime))
    }

    function markAsNotified(id) {
        return root.updateEvent(id, { notified: true })
    }

    function saveToFile() {
        const data = {
            nextId: root.nextId,
            events: root.list
        }
        
        const dir = Quickshell.env("XDG_DATA_HOME") + "/quickshell"
        Quickshell.execDetached(["mkdir", "-p", dir])
        
        const json = JSON.stringify(data, null, 2)
        const writeProcess = Process.exec("/usr/bin/bash", ["-c", 
            `echo '${json.replace(/'/g, "'\\''")}' > "${root.filePath}"`
        ])
    }

    function loadFromFile() {
        const readProcess = Process.exec("/usr/bin/cat", [root.filePath])
        
        if (readProcess.exitCode === 0 && readProcess.stdout.trim() !== "") {
            try {
                const data = JSON.parse(readProcess.stdout)
                root.list = data.events || []
                root.nextId = data.nextId || 1
                console.log("[Events] Loaded", root.list.length, "events")
            } catch (e) {
                console.warn("[Events] Failed to parse file:", e)
                root.list = []
                root.nextId = 1
            }
        } else {
            console.log("[Events] No existing file, starting fresh")
            root.list = []
            root.nextId = 1
        }
    }

    function getCategoryIcon(category) {
        switch (category) {
            case "birthday": return "cake"
            case "meeting": return "groups"
            case "deadline": return "flag"
            case "reminder": return "notifications"
            default: return "event"
        }
    }

    function getPriorityColor(priority) {
        switch (priority) {
            case "high": return "#ef4444"
            case "low": return "#6b7280"
            default: return "#3b82f6"
        }
    }
}
