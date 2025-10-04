"use client"

import type React from "react"

import { useState } from "react"
import Link from "next/link"

const API_BASE = process.env.NEXT_PUBLIC_API_BASE || "http://localhost"

export default function ValidatorPage() {
  const [ticketId, setTicketId] = useState("")
  const [tripId, setTripId] = useState("")
  const [message, setMessage] = useState("")
  const [isSuccess, setIsSuccess] = useState(false)

  const handleValidate = async (e: React.FormEvent) => {
    e.preventDefault()
    setMessage("")

    try {
      const res = await fetch(`${API_BASE}:9003/ticketing/validate`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ticketId, tripId }),
      })

      const data = await res.json()

      if (res.ok) {
        setMessage("Ticket validated successfully!")
        setIsSuccess(true)
        setTicketId("")
      } else {
        setMessage(data.message || "Validation failed")
        setIsSuccess(false)
      }
    } catch (error) {
      setMessage("Error connecting to server")
      setIsSuccess(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-4">
      <div className="w-full max-w-md space-y-6">
        <div className="text-center space-y-2">
          <Link href="/" className="text-[var(--color-primary)] hover:underline text-sm">
            ← Back to Home
          </Link>
          <h1 className="text-3xl font-bold mt-2">Ticket Validator</h1>
          <p className="text-[var(--color-text-muted)]">Scan or enter ticket ID to validate</p>
        </div>

        <form
          onSubmit={handleValidate}
          className="space-y-4 bg-[var(--color-background)] p-6 rounded-lg border border-[var(--color-border)]"
        >
          <div className="space-y-2">
            <label className="text-sm font-medium">Ticket ID</label>
            <input
              type="text"
              value={ticketId}
              onChange={(e) => setTicketId(e.target.value)}
              className="w-full px-4 py-2 border border-[var(--color-border)] rounded-lg font-mono"
              placeholder="Enter ticket ID"
              required
            />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium">Trip ID</label>
            <input
              type="text"
              value={tripId}
              onChange={(e) => setTripId(e.target.value)}
              className="w-full px-4 py-2 border border-[var(--color-border)] rounded-lg font-mono"
              placeholder="Enter trip ID"
              required
            />
          </div>

          {message && (
            <div
              className={`p-4 rounded-lg ${
                isSuccess ? "bg-[var(--color-success)] text-white" : "bg-[var(--color-danger)] text-white"
              }`}
            >
              {message}
            </div>
          )}

          <button
            type="submit"
            className="w-full py-3 bg-[var(--color-primary)] text-white rounded-lg hover:bg-[var(--color-primary-dark)] transition-colors font-semibold"
          >
            Validate Ticket
          </button>
        </form>

        <div className="bg-[var(--color-surface)] border border-[var(--color-border)] rounded-lg p-4 space-y-2">
          <h3 className="font-semibold text-sm">Instructions</h3>
          <ul className="text-sm text-[var(--color-text-muted)] space-y-1 list-disc list-inside">
            <li>Enter the ticket ID from passenger</li>
            <li>Enter the current trip ID</li>
            <li>Click validate to check ticket status</li>
            <li>Only PAID tickets can be validated</li>
          </ul>
        </div>
      </div>
    </div>
  )
}
