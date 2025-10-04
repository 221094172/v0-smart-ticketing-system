"use client"

import type React from "react"

import { useState } from "react"
import useSWR from "swr"
import Link from "next/link"

const API_BASE = process.env.NEXT_PUBLIC_API_BASE || "http://localhost"

const fetcher = (url: string) => fetch(url).then((r) => r.json())

export default function AdminPage() {
  const [routeNumber, setRouteNumber] = useState("")
  const [routeName, setRouteName] = useState("")
  const [routeType, setRouteType] = useState("BUS")
  const [origin, setOrigin] = useState("")
  const [destination, setDestination] = useState("")
  const [message, setMessage] = useState("")

  const { data: salesReport } = useSWR(`${API_BASE}:9006/admin/reports/sales`, fetcher)
  const { data: routes } = useSWR(`${API_BASE}:9006/admin/routes`, fetcher)
  const { data: passengerStats } = useSWR(`${API_BASE}:9006/admin/statistics/passengers`, fetcher)
  const { data: ticketStats } = useSWR(`${API_BASE}:9006/admin/statistics/tickets`, fetcher)

  const handleCreateRoute = async (e: React.FormEvent) => {
    e.preventDefault()
    setMessage("")

    try {
      const res = await fetch(`${API_BASE}:9002/transport/routes`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          routeNumber,
          name: routeName,
          type: routeType,
          origin,
          destination,
          stops: [origin, destination],
          distance: 10.5,
          estimatedDuration: 30,
        }),
      })

      const data = await res.json()

      if (res.ok) {
        setMessage(`Route created successfully! ID: ${data.routeId}`)
        setRouteNumber("")
        setRouteName("")
        setOrigin("")
        setDestination("")
      } else {
        setMessage("Failed to create route")
      }
    } catch (error) {
      setMessage("Error connecting to server")
    }
  }

  const handlePublishDisruption = async () => {
    try {
      const res = await fetch(`${API_BASE}:9006/admin/disruptions`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          routeId: "ALL",
          type: "DELAY",
          message: "Service delays due to maintenance",
          startTime: new Date().toISOString(),
        }),
      })

      if (res.ok) {
        setMessage("Disruption notice published successfully!")
      }
    } catch (error) {
      setMessage("Error publishing disruption")
    }
  }

  return (
    <div className="min-h-screen p-8">
      <div className="max-w-7xl mx-auto space-y-8">
        <div>
          <Link href="/" className="text-[var(--color-primary)] hover:underline text-sm">
            ← Back to Home
          </Link>
          <h1 className="text-3xl font-bold mt-2">Admin Dashboard</h1>
          <p className="text-[var(--color-text-muted)]">Manage routes, trips, and view reports</p>
        </div>

        {message && <div className="p-4 bg-[var(--color-success)] text-white rounded-lg">{message}</div>}

        <div className="grid md:grid-cols-3 gap-6">
          <div className="p-6 bg-[var(--color-background)] border border-[var(--color-border)] rounded-lg">
            <h3 className="text-sm font-medium text-[var(--color-text-muted)]">Total Revenue</h3>
            <p className="text-3xl font-bold mt-2">N${salesReport?.totalRevenue?.toFixed(2) || "0.00"}</p>
          </div>

          <div className="p-6 bg-[var(--color-background)] border border-[var(--color-border)] rounded-lg">
            <h3 className="text-sm font-medium text-[var(--color-text-muted)]">Total Tickets</h3>
            <p className="text-3xl font-bold mt-2">{ticketStats?.totalTickets || 0}</p>
          </div>

          <div className="p-6 bg-[var(--color-background)] border border-[var(--color-border)] rounded-lg">
            <h3 className="text-sm font-medium text-[var(--color-text-muted)]">Total Passengers</h3>
            <p className="text-3xl font-bold mt-2">{passengerStats?.totalPassengers || 0}</p>
          </div>
        </div>

        <div className="grid md:grid-cols-2 gap-8">
          <div className="space-y-4">
            <h2 className="text-2xl font-semibold">Create New Route</h2>
            <form
              onSubmit={handleCreateRoute}
              className="space-y-4 bg-[var(--color-background)] p-6 rounded-lg border border-[var(--color-border)]"
            >
              <div className="space-y-2">
                <label className="text-sm font-medium">Route Number</label>
                <input
                  type="text"
                  value={routeNumber}
                  onChange={(e) => setRouteNumber(e.target.value)}
                  className="w-full px-4 py-2 border border-[var(--color-border)] rounded-lg"
                  placeholder="e.g., R101"
                  required
                />
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium">Route Name</label>
                <input
                  type="text"
                  value={routeName}
                  onChange={(e) => setRouteName(e.target.value)}
                  className="w-full px-4 py-2 border border-[var(--color-border)] rounded-lg"
                  placeholder="e.g., City Center Express"
                  required
                />
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium">Type</label>
                <select
                  value={routeType}
                  onChange={(e) => setRouteType(e.target.value)}
                  className="w-full px-4 py-2 border border-[var(--color-border)] rounded-lg"
                >
                  <option value="BUS">Bus</option>
                  <option value="TRAIN">Train</option>
                </select>
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium">Origin</label>
                <input
                  type="text"
                  value={origin}
                  onChange={(e) => setOrigin(e.target.value)}
                  className="w-full px-4 py-2 border border-[var(--color-border)] rounded-lg"
                  placeholder="e.g., Windhoek Central"
                  required
                />
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium">Destination</label>
                <input
                  type="text"
                  value={destination}
                  onChange={(e) => setDestination(e.target.value)}
                  className="w-full px-4 py-2 border border-[var(--color-border)] rounded-lg"
                  placeholder="e.g., Katutura"
                  required
                />
              </div>

              <button
                type="submit"
                className="w-full py-2 bg-[var(--color-primary)] text-white rounded-lg hover:bg-[var(--color-primary-dark)] transition-colors"
              >
                Create Route
              </button>
            </form>

            <button
              onClick={handlePublishDisruption}
              className="w-full py-2 bg-[var(--color-warning)] text-white rounded-lg hover:opacity-90 transition-opacity"
            >
              Publish Service Disruption
            </button>
          </div>

          <div className="space-y-4">
            <h2 className="text-2xl font-semibold">All Routes</h2>
            <div className="space-y-3">
              {routes?.routes?.map((route: any) => (
                <div
                  key={route._id}
                  className="p-4 bg-[var(--color-background)] border border-[var(--color-border)] rounded-lg space-y-2"
                >
                  <div className="flex items-center justify-between">
                    <h3 className="font-semibold">{route.name}</h3>
                    <span className="text-xs px-2 py-1 bg-[var(--color-surface)] rounded">{route.routeNumber}</span>
                  </div>
                  <p className="text-sm text-[var(--color-text-muted)]">
                    {route.origin} → {route.destination}
                  </p>
                  <div className="flex items-center gap-2 text-xs">
                    <span
                      className={`px-2 py-1 rounded ${
                        route.status === "ACTIVE" ? "bg-[var(--color-success)] text-white" : "bg-[var(--color-surface)]"
                      }`}
                    >
                      {route.status}
                    </span>
                    <span className="text-[var(--color-text-muted)]">{route.type}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {salesReport && (
          <div className="space-y-4">
            <h2 className="text-2xl font-semibold">Sales Report</h2>
            <div className="bg-[var(--color-background)] border border-[var(--color-border)] rounded-lg p-6 space-y-4">
              <div className="grid md:grid-cols-3 gap-4">
                {Object.entries(salesReport.ticketsByType || {}).map(([type, count]) => (
                  <div key={type} className="space-y-1">
                    <p className="text-sm text-[var(--color-text-muted)]">{type} Tickets</p>
                    <p className="text-2xl font-bold">{count as number}</p>
                    <p className="text-sm text-[var(--color-text-muted)]">
                      N${(salesReport.revenueByType?.[type] || 0).toFixed(2)}
                    </p>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
