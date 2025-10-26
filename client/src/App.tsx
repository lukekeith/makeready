import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import { observer } from 'mobx-react'
import { LoginPage } from '@/pages/login/login.page'
import { HomePage } from '@/pages/home/home.page'
import { AdminPage } from '@/pages/admin/admin.page'

function App() {
  return (
    <Router>
      <div className="min-h-screen bg-background text-foreground">
        <Routes>
          <Route path="/" element={<Navigate to="/home" replace />} />
          <Route path="/login" element={<LoginPage />} />
          <Route path="/home" element={<HomePage />} />
          <Route path="/admin" element={<AdminPage />} />
        </Routes>
      </div>
    </Router>
  )
}

export default observer(App)
