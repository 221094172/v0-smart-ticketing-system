"use client"

import type React from "react"

import { useState } from "react"
import useSWR from "swr"
import Link from "next/link"

const API_BASE = process.env.NEXT_PUBLIC_API_BASE || "http://localhost"

const fetcher = (url: string) => fetch(url).then((r) => r.json())

export default function PassengerPage() {
  const [view, setView] = useState<"login" | "register" | "dashboard">("login")
  const [userId, setUserId] = useState<string | null>(null)
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [firstName, setFirstName] = useState("")
  const [lastName, setLastName] = useState("")
  const [username, setUsername] = useState("")
  const [message, setMessage] = useState("")

  const { data: profile } = useSWR(userId ? `${API_BASE}:9001/passenger/profile/${userId}` : null, fetcher)

  const { data: tickets } = useSWR(userId ? `${API_BASE}:9001/passenger/tickets/${userId}` : null, fetcher)

  const { data: routes } = useSWR(`${API_BASE}:9002/transport/routes`, fetcher)

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setMessage("")

    try {
      const res = await fetch(`${API_BASE}:9001/passenger/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      })

      const data = await res.json()

      if (res.ok) {
        setUserId(data.userId)
        setView("dashboard")
        setMessage("Login successful!")
      } else {
        setMessage(data.message || "Login failed")
      }
    } catch (error) {
      setMessage("Error connecting to server")
    }
  }

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault()
    setMessage("")

    try {
      const res = await fetch(`${API_BASE}:9001/passenger/register`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password, firstName, lastName, username }),
      })

      const data = await res.json()

      if (res.ok) {
        setMessage("Registration successful! Please login.")
        setView("login")
      } else {
        setMessage(data.message || "Registration failed")
      }
    } catch (error) {
      setMessage("Error connecting to server")
    }
  }

  const handleBuyTicket = async (tripId: string, price: number) => {
    if (!userId) return

    try {
      const res = await fetch(`${API_BASE}:9003/ticketing/tickets`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          passengerId: userId,
          tripId,
          ticketType: "SINGLE",
          amount: price,
        }),
      })

      const data = await res.json()

      if (res.ok) {
        setMessage(`Ticket purchased! ID: ${data.ticketId}`)
      } else {
        setMessage("Failed to purchase ticket")
      }
    } catch (error) {
      setMessage("Error connecting to server")
    }
  }

  if (view === "login") {
    return (
      <div className="min-h-screen flex items-center justify-center p-4">
        <div className="w-full max-w-md space-y-6">
          <div className="text-center space-y-2">
            <Link href="/" className="text-[var(--color-primary)] hover:underline text-sm">
              ← Back to Home
            </Link>
            <h1 className="text-3xl font-bold">Passenger Login</h1>
          </div>

          <form
            onSubmit={handleLogin}
            className="space-y-4 bg-[var(--color-background)] p-6 rounded-lg border border-[var(--color-border)]"
          >
            <div className="space-y-2">
              <label className="text-sm font-medium">Email</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full px-4 py-2 border border-[var(--color-border)] rounded-lg"
                required
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium">Password</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full px-4 py-2 border border-[var(--color-border)] rounded-lg"
                required
              />
            </div>

            {message && (
              <div className="p-3 bg-[var(--color-surface)] border border-[var(--color-border)] rounded-lg text-sm">
                {message}
              </div>
            )}

            <button
              type="submit"
              className="w-full py-2 bg-[var(--color-primary)] text-white rounded-lg hover:bg-[var(--color-primary-dark)] transition-colors"
            >
              Login
            </button>

            <button
              type="button"
              onClick={() => setView("register")}
              className="w-full py-2 border border-[var(--color-border)] rounded-lg hover:bg-[var(--color-surface)] transition-colors"
            >
              Create Account
            </button>
          </form>
        </div>
      </div>
    )
  }

  if (view === "register") {
    return (
      <div className="min-h-screen flex items-center justify-center p-4">
        <div className="w-full max-w-md space-y-6">
          <div className="text-center space-y-2">
            <h1 className="text-3xl font-bold">Create Account</h1>
          </div>

          <form
            onSubmit={handleRegister}
            className="space-y-4 bg-[var(--color-background)] p-6 rounded-lg border border-[var(--color-border)]"
          >
            <div className="space-y-2">
              <label className="text-sm font-medium">Username</label>
              <input
                type="text"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                className="w-full px-4 py-2 border border-[var(--color-border)] rounded-lg"
                required
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium">First Name</label>
              <input
                type="text"
                value={firstName}
                onChange={(e) => setFirstName(e.target.value)}
                className="w-full px-4 py-2 border border-[var(--color-border)] rounded-lg"
                required
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium">Last Name</label>
              <input
                type="text"
                value={lastName}
                onChange={(e) => setLastName(e.target.value)}
                className="w-full px-4 py-2 border border-[var(--color-border)] rounded-lg"
                required
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium">Email</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full px-4 py-2 border border-[var(--color-border)] rounded-lg"
                required
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium">Password</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full px-4 py-2 border border-[var(--color-border)] rounded-lg"
                required
              />
            </div>

            {message && (
              <div className="p-3 bg-[var(--color-surface)] border border-[var(--color-border)] rounded-lg text-sm">
                {message}
              </div>
            )}

            <button
              type="submit"
              className="w-full py-2 bg-[var(--color-primary)] text-white rounded-lg hover:bg-[var(--color-primary-dark)] transition-colors"
            >
              Register
            </button>

            <button
              type="button"
              onClick={() => setView("login")}
              className="w-full py-2 border border-[var(--color-border)] rounded-lg hover:bg-[var(--color-surface)] transition-colors"
            >
              Back to Login
            </button>
          </form>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen p-8">
      <div className="max-w-6xl mx-auto space-y-8">
        <div className="flex items-center justify-between">
          <div>
            <Link href="/" className="text-[var(--color-primary)] hover:underline text-sm">
              ← Back to Home
            </Link>
            <h1 className="text-3xl font-bold mt-2">Passenger Dashboard</h1>
            {profile && (
              <p className="text-[var(--color-text-muted)]">
                Welcome, {profile.firstName} {profile.lastName}
              </p>
            )}
          </div>
          <button
            onClick={() => {
              setUserId(null)
              setView("login")
            }}
            className="px-4 py-2 border border-[var(--color-border)] rounded-lg hover:bg-[var(--color-surface)] transition-colors"
          >
            Logout
          </button>
        </div>

        {message && <div className="p-4 bg-[var(--color-success)] text-white rounded-lg">{message}</div>}

        <div className="grid md:grid-cols-2 gap-8">
          <div className="space-y-4">
            <h2 className="text-2xl font-semibold">Available Routes</h2>
            <div className="space-y-3">
              {routes?.routes?.map((route: any) => (
                <div
                  key={route._id}
                  className="p-4 bg-[var(--color-background)] border border-[var(--color-border)] rounded-lg space-y-2"
                >
                  <div className="flex items-center justify-between">
                    <h3 className="font-semibold">{route.name}</h3>
                    <span className="text-xs px-2 py-1 bg-[var(--color-surface)] rounded">{route.type}</span>
                  </div>
                  <p className="text-sm text-[var(--color-text-muted)]">
                    {route.origin} → {route.destination}
                  </p>
                  <button
                    onClick={() => handleBuyTicket(route._id, 25.0)}
                    className="w-full py-2 bg-[var(--color-primary)] text-white rounded-lg hover:bg-[var(--color-primary-dark)] transition-colors text-sm"
                  >
                    Buy Ticket - N$25.00
                  </button>
                </div>
              ))}
            </div>
          </div>

          <div className="space-y-4">
            <h2 className="text-2xl font-semibold">My Tickets</h2>
            <div className="space-y-3">
              {tickets?.tickets?.length > 0 ? (
                tickets.tickets.map((ticket: any) => (
                  <div
                    key={ticket._id}
                    className="p-4 bg-[var(--color-background)] border border-[var(--color-border)] rounded-lg space-y-2"
                  >
                    <div className="flex items-center justify-between">
                      <span className="font-mono text-sm">{ticket._id}</span>
                      <span
                        className={`text-xs px-2 py-1 rounded ${
                          ticket.status === "PAID"
                            ? "bg-[var(--color-success)] text-white"
                            : ticket.status === "VALIDATED"
                              ? "bg-[var(--color-primary)] text-white"
                              : "bg-[var(--color-surface)]"
                        }`}
                      >
                        {ticket.status}
                      </span>
                    </div>
                    <div className="text-sm space-y-1">
                      <p>Type: {ticket.ticketType}</p>
                      <p>Amount: N${ticket.amount}</p>
                      <p className="text-[var(--color-text-muted)]">
                        Valid until: {new Date(ticket.validUntil).toLocaleDateString()}
                      </p>
                    </div>
                  </div>
                ))
              ) : (
                <p className="text-[var(--color-text-muted)] text-center py-8">
                  No tickets yet. Purchase a ticket to get started!
                </p>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
