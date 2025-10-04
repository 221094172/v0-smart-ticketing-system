import Link from "next/link"

export default function HomePage() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center p-8">
      <div className="max-w-4xl w-full space-y-8">
        <div className="text-center space-y-4">
          <h1 className="text-5xl font-bold text-balance">Smart Transport Ticketing System</h1>
          <p className="text-xl text-[var(--color-text-muted)] text-pretty">
            Modern distributed ticketing platform for buses and trains
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-6 mt-12">
          <Link
            href="/passenger"
            className="group p-8 bg-[var(--color-background)] border border-[var(--color-border)] rounded-lg hover:border-[var(--color-primary)] transition-colors"
          >
            <div className="space-y-3">
              <div className="w-12 h-12 bg-[var(--color-primary)] rounded-lg flex items-center justify-center text-white text-2xl">
                🎫
              </div>
              <h2 className="text-2xl font-semibold">Passenger Portal</h2>
              <p className="text-[var(--color-text-muted)] leading-relaxed">
                Register, buy tickets, and manage your travel
              </p>
            </div>
          </Link>

          <Link
            href="/admin"
            className="group p-8 bg-[var(--color-background)] border border-[var(--color-border)] rounded-lg hover:border-[var(--color-primary)] transition-colors"
          >
            <div className="space-y-3">
              <div className="w-12 h-12 bg-[var(--color-primary)] rounded-lg flex items-center justify-center text-white text-2xl">
                📊
              </div>
              <h2 className="text-2xl font-semibold">Admin Dashboard</h2>
              <p className="text-[var(--color-text-muted)] leading-relaxed">Manage routes, trips, and view reports</p>
            </div>
          </Link>

          <Link
            href="/validator"
            className="group p-8 bg-[var(--color-background)] border border-[var(--color-border)] rounded-lg hover:border-[var(--color-primary)] transition-colors"
          >
            <div className="space-y-3">
              <div className="w-12 h-12 bg-[var(--color-primary)] rounded-lg flex items-center justify-center text-white text-2xl">
                ✓
              </div>
              <h2 className="text-2xl font-semibold">Validator Interface</h2>
              <p className="text-[var(--color-text-muted)] leading-relaxed">Validate tickets on boarding</p>
            </div>
          </Link>
        </div>
      </div>
    </div>
  )
}
