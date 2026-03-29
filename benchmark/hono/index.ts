import { Hono } from 'hono'

const app = new Hono()

app.get('/', (c) => {
  return c.json({
    framework: 'Hono',
    language: 'TypeScript',
    speed: 'Blazing Fast'
  })
})

export default {
  port: 3002,
  fetch: app.fetch,
}
