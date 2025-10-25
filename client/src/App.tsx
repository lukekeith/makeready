import { BrowserRouter as Router, Routes, Route } from 'react-router-dom'
import { observer } from 'mobx-react'

function App() {
  return (
    <Router>
      <div className="min-h-screen bg-background text-foreground">
        <Routes>
          <Route path="/" element={
            <div className="flex flex-col items-center justify-center min-h-screen">
              <img src="/logo-mark.svg" alt="MakeReady" className="w-32 h-32 mb-8" />
              <h1 className="text-4xl font-bold mb-4">Welcome to MakeReady</h1>
              <p className="text-muted-foreground">Your app is ready to build!</p>
            </div>
          } />
        </Routes>
      </div>
    </Router>
  )
}

export default observer(App)
