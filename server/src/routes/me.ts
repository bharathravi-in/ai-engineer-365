import { Router } from 'express';
import { requireUser } from '../auth.js';

export const meRouter = Router();

// The caller's profile (used for the admin gate on the client). The user id and
// admin flag always come from the verified JWT, never from the request body.
meRouter.use(requireUser);

meRouter.get('/', (req, res) => {
  const user = req.authUser!;
  res.json({ id: user.id, email: user.email, is_admin: user.isAdmin });
});
