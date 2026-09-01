import { Shell } from "../../../components/Shell.jsx";
import { AdminSpace } from "../../../screens/Admin.jsx";

export const metadata = { title: "Le Choix du Ministre" };

export default function Page() {
  return <Shell><AdminSpace section="vitrine" /></Shell>;
}
